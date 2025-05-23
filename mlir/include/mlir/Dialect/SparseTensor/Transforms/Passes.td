//===-- Passes.td - Sparse tensor pass definition file -----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_SPARSETENSOR_TRANSFORMS_PASSES
#define MLIR_DIALECT_SPARSETENSOR_TRANSFORMS_PASSES

include "mlir/Pass/PassBase.td"

def SparseTensorRewrite : Pass<"sparse-tensor-rewrite", "ModuleOp"> {
  let summary = "Applies sparse tensor rewriting rules prior to sparsification";
  let description = [{
    A pass that applies rewriting rules to sparse tensor operations prior
    to running the actual sparsification pass.
  }];
  let constructor = "mlir::createSparseTensorRewritePass()";
  let dependentDialects = [
    "arith::ArithDialect",
    "bufferization::BufferizationDialect",
    "linalg::LinalgDialect",
    "memref::MemRefDialect",
    "scf::SCFDialect",
    "sparse_tensor::SparseTensorDialect",
  ];
  let options = [
    Option<"enableRuntimeLibrary", "enable-runtime-library", "bool",
           "true", "Enable runtime library for manipulating sparse tensors">,
    Option<"enableForeach", "enable-foreach", "bool",
           "true", "Enable rewriting rules for the foreach operator">,
    Option<"enableConvert", "enable-convert", "bool",
           "true", "Enable rewriting rules for the convert operator">,
  ];
}

def SparsificationPass : Pass<"sparsification", "ModuleOp"> {
  let summary = "Automatically generate sparse tensor code from sparse tensor types";
  let description = [{
    A pass that implements the core functionality of a **sparse compiler**.
    Each Linalg operation (MLIR's tensor index notation) that operates on
    sparse tensor types is converted into code in which the sparsity is
    explicit both in terms of co-iterating looping logic as well as
    selected sparse storage schemes.

    See the `SparseTensor` dialect documentation for more background.

    Example input:

    ```mlir
    #matvec = {
      indexing_maps = [
        affine_map<(i,j) -> (i,j)>, // A
        affine_map<(i,j) -> (j)>,   // b
        affine_map<(i,j) -> (i)>    // x (out)
      ],
      iterator_types = ["parallel", "reduction"],
      doc = "X(i) += A(i,j) * B(j)"
    }

    // Multiply a sparse matrix A with a dense vector b into a dense vector x.
    func.func @kernel_matvec(%arga: tensor<?x?xf64, #SparseMatrix>,
                        %argb: tensor<?xf64>,
                        %argx: tensor<?xf64>) -> tensor<?xf64> {
      %0 = linalg.generic #matvec
        ins(%arga, %argb: tensor<?x?xf64, #SparseMatrix>, tensor<?xf64>)
        outs(%argx: tensor<?xf64>) {
        ^bb(%a: f64, %b: f64, %x: f64):
          %0 = arith.mulf %a, %b : f64
          %1 = arith.addf %x, %0 : f64
          linalg.yield %1 : f64
      } -> tensor<?xf64>
      return %0 : tensor<?xf64>
    }
    ```
  }];
  let constructor = "mlir::createSparsificationPass()";
  let dependentDialects = [
    "AffineDialect",
    "arith::ArithDialect",
    "bufferization::BufferizationDialect",
    "LLVM::LLVMDialect",
    "linalg::LinalgDialect",
    "memref::MemRefDialect",
    "scf::SCFDialect",
    "sparse_tensor::SparseTensorDialect",
  ];
  // TODO(57514): These enum options are duplicated in Passes.h.
  let options = [
    Option<"parallelization", "parallelization-strategy", "mlir::SparseParallelizationStrategy",
           "mlir::SparseParallelizationStrategy::kNone",
           "Set the parallelization strategy", [{llvm::cl::values(
             clEnumValN(mlir::SparseParallelizationStrategy::kNone, "none",
                        "Turn off sparse parallelization."),
             clEnumValN(mlir::SparseParallelizationStrategy::kDenseOuterLoop,
                        "dense-outer-loop",
                        "Enable dense outer loop sparse parallelization."),
             clEnumValN(mlir::SparseParallelizationStrategy::kAnyStorageOuterLoop,
                        "any-storage-outer-loop",
                        "Enable sparse parallelization regardless of storage for the outer loop."),
             clEnumValN(mlir::SparseParallelizationStrategy::kDenseAnyLoop,
                        "dense-any-loop",
                        "Enable dense parallelization for any loop."),
             clEnumValN(mlir::SparseParallelizationStrategy::kAnyStorageAnyLoop,
                        "any-storage-any-loop",
                        "Enable sparse parallelization for any storage and loop."))}]>
  ];
}

def SparseTensorConversionPass : Pass<"sparse-tensor-conversion", "ModuleOp"> {
  let summary = "Convert sparse tensors and primitives to library calls";
  let description = [{
    A pass that converts sparse tensor primitives into calls into a runtime
    support library. Sparse tensor types are converted into opaque pointers
    to the underlying sparse storage schemes.

    The use of opaque pointers together with runtime support library keeps
    the conversion relatively simple, but at the expense of IR opacity,
    which obscures opportunities for subsequent optimization of the IR.
    An alternative is provided by the SparseTensorCodegen pass.

    Example of the conversion:

    ```mlir
      Before:
        %c1 = arith.constant 1 : index
        %0 = sparse_tensor.pointers %arg0, %c1
          : tensor<8x8xf32, #sparse_tensor.encoding<{
              dimLevelType = [ "dense", "compressed" ],
              pointerBitWidth = 0,
              indexBitWidth = 0
            }>> to memref<?xindex>

      After:
        %c1 = arith.constant 1 : index
        %0 = call @sparsePointers(%arg0, %c1) : (!llvm.ptr<i8>, index) -> memref<?xindex>
    ```
  }];
  let constructor = "mlir::createSparseTensorConversionPass()";
  let dependentDialects = [
    "arith::ArithDialect",
    "bufferization::BufferizationDialect",
    "LLVM::LLVMDialect",
    "linalg::LinalgDialect",
    "memref::MemRefDialect",
    "scf::SCFDialect",
    "sparse_tensor::SparseTensorDialect",
  ];
  let options = [
    Option<"sparseToSparse", "s2s-strategy", "int32_t", "0",
           "Set the strategy for sparse-to-sparse conversion">,
  ];
}

def SparseTensorCodegen : Pass<"sparse-tensor-codegen", "ModuleOp"> {
  let summary = "Convert sparse tensors and primitives to actual code";
  let description = [{
    A pass that converts sparse tensor types and primitives to actual
    compiler visible buffers and compiler IR that implements these
    primitives on the selected sparse tensor storage schemes.

    This pass provides an alternative to the SparseTensorConversion pass,
    eliminating the dependence on a runtime support library, and providing
    much more opportunities for subsequent compiler optimization of the
    generated code.

    Example of the conversion:

    ```mlir
    TBD
    ```
  }];
  let constructor = "mlir::createSparseTensorCodegenPass()";
  let dependentDialects = [
    "arith::ArithDialect",
    "bufferization::BufferizationDialect",
    "linalg::LinalgDialect",
    "memref::MemRefDialect",
    "scf::SCFDialect",
    "sparse_tensor::SparseTensorDialect",
  ];
  let options = [
    Option<"enableBufferInitialization", "enable-buffer-initialization", "bool",
           "false", "Enable zero-initialization of the memory buffers">,
  ];
}

def SparseBufferRewrite : Pass<"sparse-buffer-rewrite", "ModuleOp"> {
  let summary = "Rewrite sparse primitives on buffers to actual code";
  let description = [{
    A pass that rewrites sparse primitives on buffers to the MLIR implementation
    of the primitives. For example, sparse_tensor.sort operator is implemented
    in this pass.
  }];
  let constructor = "mlir::createSparseBufferRewritePass()";
  let dependentDialects = [
    "arith::ArithDialect",
    "linalg::LinalgDialect",
    "memref::MemRefDialect",
    "scf::SCFDialect",
    "sparse_tensor::SparseTensorDialect",
  ];
  let options = [
    Option<"enableBufferInitialization", "enable-buffer-initialization", "bool",
           "false", "Enable zero-initialization of the memory buffers">,
  ];
}

#endif // MLIR_DIALECT_SPARSETENSOR_TRANSFORMS_PASSES
