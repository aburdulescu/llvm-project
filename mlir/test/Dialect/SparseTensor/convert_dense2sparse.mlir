// RUN: mlir-opt %s --sparse-tensor-conversion --canonicalize --cse | FileCheck %s
// RUN: mlir-opt %s --sparse-tensor-rewrite="enable-runtime-library=false enable-foreach=false" \
// RUN: --canonicalize --cse | FileCheck %s --check-prefix=CHECK-RWT

#SparseVector = #sparse_tensor.encoding<{
  dimLevelType = ["compressed"]
}>

#CSR = #sparse_tensor.encoding<{
  dimLevelType = ["dense", "compressed"]
}>

#SparseTensor = #sparse_tensor.encoding<{
  dimLevelType = ["dense", "compressed", "compressed"],
  dimOrdering = affine_map<(i,j,k) -> (k,i,j)>
}>

// CHECK-LABEL: func @sparse_convert_1d(
//  CHECK-SAME: %[[A:.*]]: tensor<?xi32>) -> !llvm.ptr<i8> {
//   CHECK-DAG: %[[EmptyCOO:.*]] = arith.constant 4 : i32
//   CHECK-DAG: %[[FromCOO:.*]] = arith.constant 2 : i32
//   CHECK-DAG: %[[I0:.*]] = arith.constant 0 : i32
//   CHECK-DAG: %[[C0:.*]] = arith.constant 0 : index
//   CHECK-DAG: %[[C1:.*]] = arith.constant 1 : index
//   CHECK-DAG: %[[U:.*]] = tensor.dim %[[A]], %[[C0]] : tensor<?xi32>
//   CHECK-DAG: %[[P:.*]] = memref.alloca() : memref<1xi8>
//   CHECK-DAG: %[[Q:.*]] = memref.alloca() : memref<1xindex>
//   CHECK-DAG: %[[R:.*]] = memref.alloca() : memref<1xindex>
//   CHECK-DAG: %[[X:.*]] = memref.cast %[[P]] : memref<1xi8> to memref<?xi8>
//   CHECK-DAG: %[[Y:.*]] = memref.cast %[[Q]] : memref<1xindex> to memref<?xindex>
//   CHECK-DAG: %[[Z:.*]] = memref.cast %[[R]] : memref<1xindex> to memref<?xindex>
//       CHECK: %[[NP:.*]] = llvm.mlir.null : !llvm.ptr<i8>
//       CHECK: %[[C:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[EmptyCOO]], %[[NP]])
//       CHECK: %[[M:.*]] = memref.alloca() : memref<1xindex>
//       CHECK: %[[T:.*]] = memref.cast %[[M]] : memref<1xindex> to memref<?xindex>
//       CHECK: %[[BUF:.*]] = memref.alloca() : memref<i32>
//       CHECK: scf.for %[[I:.*]] = %[[C0]] to %[[U]] step %[[C1]] {
//       CHECK:   %[[E:.*]] = tensor.extract %[[A]][%[[I]]] : tensor<?xi32>
//       CHECK:   %[[N:.*]] = arith.cmpi ne, %[[E]], %[[I0]] : i32
//       CHECK:   scf.if %[[N]] {
//       CHECK:     memref.store %[[I]], %[[M]][%[[C0]]] : memref<1xindex>
//       CHECK:     memref.store %[[E]], %[[BUF]][] : memref<i32>
//       CHECK:     call @addEltI32(%[[C]], %[[BUF]], %[[T]], %[[Z]])
//       CHECK:   }
//       CHECK: }
//       CHECK: %[[T:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[FromCOO]], %[[C]])
//       CHECK: call @delSparseTensorCOOI32(%[[C]])
//       CHECK: return %[[T]] : !llvm.ptr<i8>
func.func @sparse_convert_1d(%arg0: tensor<?xi32>) -> tensor<?xi32, #SparseVector> {
  %0 = sparse_tensor.convert %arg0 : tensor<?xi32> to tensor<?xi32, #SparseVector>
  return %0 : tensor<?xi32, #SparseVector>
}

// CHECK-LABEL: func @sparse_convert_complex(
//  CHECK-SAME: %[[A:.*]]: tensor<100xcomplex<f64>>) -> !llvm.ptr<i8> {
//   CHECK-DAG: %[[CC:.*]] = complex.constant [0.000000e+00, 0.000000e+00] : complex<f64>
//   CHECK-DAG: %[[C0:.*]] = arith.constant 0 : index
//   CHECK-DAG: %[[C1:.*]] = arith.constant 1 : index
//   CHECK-DAG: %[[C100:.*]] = arith.constant 100 : index
//       CHECK: scf.for %[[I:.*]] = %[[C0]] to %[[C100]] step %[[C1]] {
//       CHECK:   %[[E:.*]] = tensor.extract %[[A]][%[[I]]] : tensor<100xcomplex<f64>>
//       CHECK:   %[[N:.*]] = complex.neq %[[E]], %[[CC]] : complex<f64>
//       CHECK:   scf.if %[[N]] {
//       CHECK:     memref.store %[[I]], %{{.*}}[%[[C0]]] : memref<1xindex>
//       CHECK:     call @addEltC64
//       CHECK:   }
//       CHECK: }
//       CHECK: %[[T:.*]] = call @newSparseTensor
//       CHECK: call @delSparseTensorCOOC64
//       CHECK: return %[[T]] : !llvm.ptr<i8>
func.func @sparse_convert_complex(%arg0: tensor<100xcomplex<f64>>) -> tensor<100xcomplex<f64>, #SparseVector> {
  %0 = sparse_tensor.convert %arg0 : tensor<100xcomplex<f64>> to tensor<100xcomplex<f64>, #SparseVector>
  return %0 : tensor<100xcomplex<f64>, #SparseVector>
}

// CHECK-LABEL: func @sparse_convert_2d(
//  CHECK-SAME: %[[A:.*]]: tensor<2x4xf64>) -> !llvm.ptr<i8>
//   CHECK-DAG: %[[EmptyCOO:.*]] = arith.constant 4 : i32
//   CHECK-DAG: %[[FromCOO:.*]] = arith.constant 2 : i32
//   CHECK-DAG: %[[C0:.*]] = arith.constant 0 : index
//   CHECK-DAG: %[[C1:.*]] = arith.constant 1 : index
//   CHECK-DAG: %[[P:.*]] = memref.alloca() : memref<2xi8>
//   CHECK-DAG: %[[Q:.*]] = memref.alloca() : memref<2xindex>
//   CHECK-DAG: %[[R:.*]] = memref.alloca() : memref<2xindex>
//   CHECK-DAG: %[[X:.*]] = memref.cast %[[P]] : memref<2xi8> to memref<?xi8>
//   CHECK-DAG: %[[Y:.*]] = memref.cast %[[Q]] : memref<2xindex> to memref<?xindex>
//   CHECK-DAG: %[[Z:.*]] = memref.cast %[[R]] : memref<2xindex> to memref<?xindex>
//       CHECK: %[[NP:.*]] = llvm.mlir.null : !llvm.ptr<i8>
//       CHECK: %[[C:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[EmptyCOO]], %[[NP]])
//       CHECK: %[[M:.*]] = memref.alloca() : memref<2xindex>
//       CHECK: %[[T:.*]] = memref.cast %[[M]] : memref<2xindex> to memref<?xindex>
//       CHECK: %[[BUF:.*]] = memref.alloca() : memref<f64>
//       CHECK: scf.for %[[I:.*]] = %[[C0]] to %{{.*}} step %[[C1]] {
//       CHECK:   scf.for %[[J:.*]] = %[[C0]] to %{{.*}} step %[[C1]] {
//       CHECK:     %[[E:.*]] = tensor.extract %[[A]][%[[I]], %[[J]]] : tensor<2x4xf64>
//       CHECK:     memref.store %[[I]], %[[M]][%[[C0]]] : memref<2xindex>
//       CHECK:     memref.store %[[J]], %[[M]][%[[C1]]] : memref<2xindex>
//       CHECK:     memref.store %[[E]], %[[BUF]][] : memref<f64>
//       CHECK:     call @addEltF64(%[[C]], %[[BUF]], %[[T]], %[[Z]])
//       CHECK:   }
//       CHECK: }
//       CHECK: %[[T:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[FromCOO]], %[[C]])
//       CHECK: call @delSparseTensorCOOF64(%[[C]])
//       CHECK: return %[[T]] : !llvm.ptr<i8>

// CHECK-RWT-LABEL:   func.func @sparse_convert_2d(
//  CHECK-RWT-SAME:     %[[T0:.*]]: tensor<2x4xf64>) -> tensor<2x4xf64, #sparse_tensor.encoding<{ dimLevelType = [ "dense", "compressed" ] }>> {
//       CHECK-RWT:     %[[T1:.*]] = bufferization.alloc_tensor()
//       CHECK-RWT:     %[[T2:.*]] = sparse_tensor.foreach in %[[T0]] init(%[[T1]])
//       CHECK-RWT:     ^bb0(%[[L0I0:.*]]: index, %[[L0I1:.*]]: index, %[[L0V:.*]]: f64, %[[L0T:.*]]: tensor
//       CHECK-RWT:        %[[CMP:.*]] = arith.cmpf une, %[[L0V]]
//       CHECK-RWT:        %[[IFR:.*]] = scf.if %[[CMP]]
//       CHECK-RWT:          %[[L0T2:.*]] = sparse_tensor.insert %[[L0V]] into %[[L0T]]{{\[}}%[[L0I0]], %[[L0I1]]]
//       CHECK-RWT:          scf.yield %[[L0T2]]
//       CHECK-RWT:        } else {
//       CHECK-RWT:          scf.yield %[[L0T]]
//       CHECK-RWT:        }
//       CHECK-RWT:        sparse_tensor.yield %[[IFR]]
//       CHECK-RWT:     }
//       CHECK-RWT:     %[[COO:.*]] = sparse_tensor.load %[[T2]] hasInserts
//       CHECK-RWT:     %[[I0:.*]] = sparse_tensor.indices %[[COO]] {dimension = 0 : index}
//       CHECK-RWT:     %[[I1:.*]] = sparse_tensor.indices %[[COO]] {dimension = 1 : index}
//       CHECK-RWT:     %[[NNZ:.*]] = sparse_tensor.number_of_entries %[[COO]]
//       CHECK-RWT:     %[[V:.*]] = sparse_tensor.values %[[COO]]
//       CHECK-RWT:     sparse_tensor.sort %[[NNZ]], %[[I0]], %[[I1]] jointly %[[V]] : memref<?xindex>, memref<?xindex> jointly memref<?xf64>
//       CHECK-RWT:     %[[T3:.*]] = bufferization.alloc_tensor()
//       CHECK-RWT:     %[[T4:.*]] = sparse_tensor.foreach in %[[COO]] init(%[[T3]])
//       CHECK-RWT:     ^bb0(%[[L1I0:.*]]: index, %[[L1I1:.*]]: index, %[[L1V:.*]]: f64, %[[L1T:.*]]: tensor
//       CHECK-RWT:       %[[L1T2:.*]] = sparse_tensor.insert %[[L1V]] into %[[L1T]]{{\[}}%[[L1I0]], %[[L1I1]]]
//       CHECK-RWT:       sparse_tensor.yield %[[L1T2]]
//       CHECK-RWT:     }
//       CHECK-RWT:     %[[T5:.*]] = sparse_tensor.load %[[T4]] hasInserts
//       CHECK-RWT:     %[[T6:.*]] = sparse_tensor.convert %[[T5]]
//       CHECK-RWT:     bufferization.dealloc_tensor %[[COO]]
//       CHECK-RWT:     return %[[T6]]
//       CHECK-RWT:   }
func.func @sparse_convert_2d(%arg0: tensor<2x4xf64>) -> tensor<2x4xf64, #CSR> {
  %0 = sparse_tensor.convert %arg0 : tensor<2x4xf64> to tensor<2x4xf64, #CSR>
  return %0 : tensor<2x4xf64, #CSR>
}

// CHECK-LABEL: func @sparse_constant() -> !llvm.ptr<i8> {
//   CHECK-DAG: %[[EmptyCOO:.*]] = arith.constant 4 : i32
//   CHECK-DAG: %[[FromCOO:.*]] = arith.constant 2 : i32
//   CHECK-DAG: %[[C0:.*]] = arith.constant 0 : index
//   CHECK-DAG: %[[C1:.*]] = arith.constant 1 : index
//   CHECK-DAG: %[[C2:.*]] = arith.constant 2 : index
//   CHECK-DAG: %[[P:.*]] = memref.alloca() : memref<2xi8>
//   CHECK-DAG: %[[Q:.*]] = memref.alloca() : memref<2xindex>
//   CHECK-DAG: %[[R:.*]] = memref.alloca() : memref<2xindex>
//   CHECK-DAG: %[[X:.*]] = memref.cast %[[P]] : memref<2xi8> to memref<?xi8>
//   CHECK-DAG: %[[Y:.*]] = memref.cast %[[Q]] : memref<2xindex> to memref<?xindex>
//   CHECK-DAG: %[[Z:.*]] = memref.cast %[[R]] : memref<2xindex> to memref<?xindex>
//       CHECK: %[[NP:.*]] = llvm.mlir.null : !llvm.ptr<i8>
//       CHECK: %[[C:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[EmptyCOO]], %[[NP]])
//       CHECK: %[[M:.*]] = memref.alloca() : memref<2xindex>
//       CHECK: %[[N:.*]] = memref.cast %[[M]] : memref<2xindex> to memref<?xindex>
//       CHECK: %[[BUF:.*]] = memref.alloca() : memref<f32>
//       CHECK: scf.for %[[I:.*]] = %[[C0]] to %[[C2]] step %[[C1]] {
//   CHECK-DAG:   memref.store %{{.*}}, %[[M]][%[[C0]]] : memref<2xindex>
//   CHECK-DAG:   memref.store %{{.*}}, %[[M]][%[[C1]]] : memref<2xindex>
//   CHECK-DAG:   %[[V:.*]] = tensor.extract %{{.*}}[%[[I]]] : tensor<2xf32>
//       CHECK:   memref.store %[[V]], %[[BUF]][] : memref<f32>
//       CHECK:   call @addEltF32(%{{.*}}, %[[BUF]], %[[N]], %{{.*}})
//       CHECK: }
//       CHECK: %[[T:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[FromCOO]], %[[C]])
//       CHECK: call @delSparseTensorCOOF32(%[[C]])
//       CHECK: return %[[T]] : !llvm.ptr<i8>

// CHECK-RWT-LABEL:   func.func @sparse_constant() -> tensor<8x7xf32, #sparse_tensor.encoding<{ dimLevelType = [ "dense", "compressed" ] }>> {
//       CHECK-RWT:     %[[F0:.*]] = arith.constant sparse<{{\[\[}}0, 0], [1, 6]], [1.000000e+00, 5.000000e+00]> : tensor<8x7xf32>
//       CHECK-RWT:     %[[T0:.*]] = bufferization.alloc_tensor()
//       CHECK-RWT:     %[[T1:.*]] = sparse_tensor.foreach in %[[F0]] init(%[[T0]])
//       CHECK-RWT:     ^bb0(%[[L0I0:.*]]: index, %[[L0I1:.*]]: index, %[[L0V:.*]]: f32, %[[L0T:.*]]: tensor
//       CHECK-RWT:       %[[L0T2:.*]] = sparse_tensor.insert %[[L0V]] into %[[L0T]]{{\[}}%[[L0I0]], %[[L0I1]]]
//       CHECK-RWT:       sparse_tensor.yield %[[L0T2]]
//       CHECK-RWT:     }
//       CHECK-RWT:     %[[COO:.*]] = sparse_tensor.load %[[T1]] hasInserts
//       CHECK-RWT:     %[[I0:.*]] = sparse_tensor.indices %[[COO]] {dimension = 0 : index}
//       CHECK-RWT:     %[[I1:.*]] = sparse_tensor.indices %[[COO]] {dimension = 1 : index}
//       CHECK-RWT:     %[[NNZ:.*]] = sparse_tensor.number_of_entries %[[COO]]
//       CHECK-RWT:     %[[V:.*]] = sparse_tensor.values %[[COO]]
//       CHECK-RWT:     sparse_tensor.sort %[[NNZ]], %[[I0]], %[[I1]] jointly %[[V]] : memref<?xindex>, memref<?xindex> jointly memref<?xf32>
//       CHECK-RWT:     %[[T3:.*]] = bufferization.alloc_tensor()
//       CHECK-RWT:     %[[T4:.*]] = sparse_tensor.foreach in %[[COO]] init(%[[T3]])
//       CHECK-RWT:     ^bb0(%[[L1I0:.*]]: index, %[[L1I1:.*]]: index, %[[L1V:.*]]: f32, %[[L1T:.*]]: tensor
//       CHECK-RWT:       %[[L1T2:.*]] = sparse_tensor.insert %[[L1V]] into %[[L1T]]{{\[}}%[[L1I0]], %[[L1I1]]]
//       CHECK-RWT:       sparse_tensor.yield %[[L1T2]]
//       CHECK-RWT:     }
//       CHECK-RWT:     %[[T5:.*]] = sparse_tensor.load %[[T4]] hasInserts
//       CHECK-RWT:     %[[T6:.*]] = sparse_tensor.convert %[[T5]]
//       CHECK-RWT:     bufferization.dealloc_tensor %[[COO]]
//       CHECK-RWT:     return %[[T6]]
//       CHECK-RWT:   }
func.func @sparse_constant() -> tensor<8x7xf32, #CSR>{
  // Initialize a tensor.
  %0 = arith.constant sparse<[[0, 0], [1, 6]], [1.0, 5.0]> : tensor<8x7xf32>
  // Convert the tensor to a sparse tensor.
  %1 = sparse_tensor.convert %0 : tensor<8x7xf32> to tensor<8x7xf32, #CSR>
  return %1 : tensor<8x7xf32, #CSR>
}

// CHECK-LABEL: func @sparse_convert_3d(
//  CHECK-SAME: %[[A:.*]]: tensor<?x?x?xf64>) -> !llvm.ptr<i8>
//   CHECK-DAG: %[[EmptyCOO:.*]] = arith.constant 4 : i32
//   CHECK-DAG: %[[FromCOO:.*]] = arith.constant 2 : i32
//   CHECK-DAG: %[[C0:.*]] = arith.constant 0 : index
//   CHECK-DAG: %[[C1:.*]] = arith.constant 1 : index
//   CHECK-DAG: %[[C2:.*]] = arith.constant 2 : index
//   CHECK-DAG: %[[U1:.*]] = tensor.dim %[[A]], %[[C0]] : tensor<?x?x?xf64>
//   CHECK-DAG: %[[U2:.*]] = tensor.dim %[[A]], %[[C1]] : tensor<?x?x?xf64>
//   CHECK-DAG: %[[U3:.*]] = tensor.dim %[[A]], %[[C2]] : tensor<?x?x?xf64>
//   CHECK-DAG: %[[P:.*]] = memref.alloca() : memref<3xi8>
//   CHECK-DAG: %[[Q:.*]] = memref.alloca() : memref<3xindex>
//   CHECK-DAG: %[[R:.*]] = memref.alloca() : memref<3xindex>
//   CHECK-DAG: %[[X:.*]] = memref.cast %[[P]] : memref<3xi8> to memref<?xi8>
//   CHECK-DAG: %[[Y:.*]] = memref.cast %[[Q]] : memref<3xindex> to memref<?xindex>
//   CHECK-DAG: %[[Z:.*]] = memref.cast %[[R]] : memref<3xindex> to memref<?xindex>
//       CHECK: %[[NP:.*]] = llvm.mlir.null : !llvm.ptr<i8>
//       CHECK: %[[C:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[EmptyCOO]], %[[NP]])
//       CHECK: %[[M:.*]] = memref.alloca() : memref<3xindex>
//       CHECK: %[[N:.*]] = memref.cast %[[M]] : memref<3xindex> to memref<?xindex>
//       CHECK: %[[BUF:.*]] = memref.alloca() : memref<f64>
//       CHECK: scf.for %[[I:.*]] = %[[C0]] to %[[U1]] step %[[C1]] {
//       CHECK:   scf.for %[[J:.*]] = %[[C0]] to %[[U2]] step %[[C1]] {
//       CHECK:     scf.for %[[K:.*]] = %[[C0]] to %[[U3]] step %[[C1]] {
//       CHECK:       %[[E:.*]] = tensor.extract %[[A]][%[[I]], %[[J]], %[[K]]] : tensor<?x?x?xf64>
//       CHECK:       memref.store %[[I]], %[[M]][%[[C0]]] : memref<3xindex>
//       CHECK:       memref.store %[[J]], %[[M]][%[[C1]]] : memref<3xindex>
//       CHECK:       memref.store %[[K]], %[[M]][%[[C2]]] : memref<3xindex>
//       CHECK:       memref.store %[[E]], %[[BUF]][] : memref<f64>
//       CHECK:       call @addEltF64(%[[C]], %[[BUF]], %[[N]], %[[Z]])
//       CHECK:     }
//       CHECK:   }
//       CHECK: }
//       CHECK: %[[T:.*]] = call @newSparseTensor(%[[X]], %[[Y]], %[[Z]], %{{.*}}, %{{.*}}, %{{.*}}, %[[FromCOO]], %[[C]])
//       CHECK: call @delSparseTensorCOOF64(%[[C]])
//       CHECK: return %[[T]] : !llvm.ptr<i8>
func.func @sparse_convert_3d(%arg0: tensor<?x?x?xf64>) -> tensor<?x?x?xf64, #SparseTensor> {
  %0 = sparse_tensor.convert %arg0 : tensor<?x?x?xf64> to tensor<?x?x?xf64, #SparseTensor>
  return %0 : tensor<?x?x?xf64, #SparseTensor>
}
