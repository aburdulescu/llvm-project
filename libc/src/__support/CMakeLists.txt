add_subdirectory(CPP)

add_header_library(
  blockstore
  HDRS
    blockstore.h
)

add_header_library(
  builtin_wrappers
  HDRS
    builtin_wrappers.h
  DEPENDS
    libc.src.__support.CPP.type_traits
)

add_header_library(
  common
  HDRS
    architectures.h
    common.h
    endian.h
    sanitizer.h
)

add_header_library(
  ctype_utils
  HDRS
    ctype_utils.h
)

add_header_library(
  str_to_integer
  HDRS
    str_to_integer.h
  DEPENDS
    .ctype_utils
    libc.include.errno
    libc.src.errno.errno
    libc.src.__support.CPP.limits
)

add_header_library(
  integer_to_string
  HDRS
    integer_to_string.h
  DEPENDS
    libc.src.__support.CPP.span
    libc.src.__support.CPP.string_view
    libc.src.__support.CPP.type_traits
)


add_header_library(
  float_to_string
  HDRS
    float_to_string.h
    ryu_constants.h
  DEPENDS
    libc.src.__support.CPP.type_traits
    libc.src.__support.FPUtil.fp_bits
)

add_header_library(
  high_precision_decimal
  HDRS
    high_precision_decimal.h
  DEPENDS
    .str_to_integer
)

add_header_library(
  str_to_float
  HDRS
    str_to_float.h
  DEPENDS
    .ctype_utils
    .high_precision_decimal
    .str_to_integer
    .uint128
    libc.include.errno
    libc.src.__support.CPP.limits
    libc.src.__support.FPUtil.fp_bits
    libc.src.__support.builtin_wrappers
    libc.src.errno.errno
)


add_header_library(
  integer_operations
  HDRS
    integer_operations.h
)

add_header_library(
  arg_list
  HDRS
    arg_list.h
)

add_header_library(
  fixedvector
  HDRS
    fixedvector.h
  DEPENDS
    libc.src.__support.CPP.array
)

add_header_library(
  uint
  HDRS
    UInt.h
  DEPENDS
    libc.src.__support.CPP.array
)

add_header_library(
  uint128
  HDRS
    UInt128.h
  DEPENDS
    .uint
)

add_subdirectory(FPUtil)
add_subdirectory(OSUtil)
add_subdirectory(StringUtil)

# Thread support is used by other "File". So, we add the "threads"
# before "File".
add_subdirectory(threads)

add_subdirectory(File)
