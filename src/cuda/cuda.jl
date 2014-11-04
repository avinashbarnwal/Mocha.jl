# a simplified CUDA module, adapted from github.com/JuliaGPU/CUDA.jl
export CUDA
module CUDA
export CuPtr

const driver_error_descriptions = (Int=>ASCIIString)[
  0 => "Success",
  1 => "Invalid value",
  2 => "Out of memory",
  3 => "Driver not initialized",
  4 => "Driver being shutdown",
  5 => "Profiler disabled",
  6 => "Profiler not initialized",
  7 => "Profiler already started",
  8 => "Profiler already stopped",
  100 => "No CUDA-capable device",
  101 => "Invalid device ordinal",
  200 => "Invalid kernel image",
  201 => "Invalid context",
  202 => "Context already current",
  205 => "Map operation failed",
  206 => "Unmap operation failed",
  207 => "Array mapped",
  208 => "Resource already mapped",
  209 => "No kernel image available/suitable for GPU",
  210 => "Resource already acquired",
  211 => "Resource not mapped",
  212 => "Resource not mapped as array",
  213 => "Resource not mapped as pointer",
  214 => "Uncorrectable ECC error detected",
  215 => "Unsupported limit",
  216 => "Context already in use",
  217 => "Peer access not supported",
  218 => "PTX JIT compilation failed",
  300 => "Invalid kernel source",
  301 => "File not found",
  302 => "Shared object symbol not found",
  303 => "Shared object initialization failed",
  304 => "OS call failed",
  400 => "Invalid handle",
  500 => "Named symbol not found",
  600 => "Not ready",
  700 => "Kernel launch failed",
  701 => "Launch out of resources",
  702 => "Launch timeout",
  703 => "Incompatible texturing mode",
  704 => "Peer access already enabled",
  705 => "Peer access not enabled",
  708 => "Primary context already active",
  709 => "Context destroyed",
  710 => "Assertion triggered failure",
  711 => "Too many peers",
  712 => "Host memory already registered",
  713 => "Host memory not registered",
  714 => "Device stack error",
  715 => "Device illegal instruction",
  716 => "Device load or store instruction on unaligned memory address",
  717 => "Device instruction on address not belonging to an allowed space",
  718 => "Device program counter wrapped its address space",
  719 => "Device exception while executing a kernel",
  800 => "Operation not permitted",
  801 => "Operation not supported",
  999 => "Unknown error"
]

immutable CuDriverError <: Exception
  code::Int
end

import Base.show
show(io::IO, error::CuDriverError) = print(io, driver_error_descriptions[error.code])

macro cucall(fv, argtypes, args...)
  f = eval(fv)
  args = map(esc, args)
  quote
    _curet = ccall( ($(Meta.quot(f)), "libcuda"), Cint, $argtypes, $(args...) )
    if _curet != 0
      throw(CuDriverError(int(_curet)))
    end
  end
end

function init()
  @cucall(:cuInit, (Cint,), 0)
end

############################################################
# Device and Context
############################################################
immutable CuDevice
  ordinal::Cint
  handle::Cint

  function CuDevice(i::Int)
    ordinal = convert(Cint, i)
    a = Cint[0]
    @cucall(:cuDeviceGet, (Ptr{Cint}, Cint), a, ordinal)
    handle = a[1]
    new(ordinal, handle)
  end
end

immutable CuContext
    handle::Ptr{Void}
end

const CTX_SCHED_AUTO  = 0x00
const CTX_SCHED_SPIN  = 0x01
const CTX_SCHED_YIELD = 0x02
const CTX_SCHED_BLOCKING_SYNC = 0x04
const CTX_MAP_HOST = 0x08
const CTX_LMEM_RESIZE_TO_MAX = 0x10

function create_context(dev::CuDevice, flags::Integer)
  a = Array(Ptr{Void}, 1)
  @cucall(:cuCtxCreate_v2, (Ptr{Ptr{Void}}, Cuint, Cint), a, flags, dev.handle)
  return CuContext(a[1])
end

create_context(dev::CuDevice) = create_context(dev, 0)

function destroy(ctx::CuContext)
  @cucall(:cuCtxDestroy_v2, (Ptr{Void},), ctx.handle)
end

############################################################
# Memory allocation
############################################################
typealias CUdeviceptr Uint64

immutable CuPtr
  p::CUdeviceptr

  CuPtr() = new(convert(CUdeviceptr, 0))
  CuPtr(p::CUdeviceptr) = new(p)
end

function cualloc(T::Type, len::Integer)
  a = CUdeviceptr[0]
  nbytes = int(len) * sizeof(T)
  @cucall(:cuMemAlloc_v2, (Ptr{CUdeviceptr}, Csize_t), a, nbytes)
  return CuPtr(a[1])
end

function free(p::CuPtr)
  @cucall(:cuMemFree_v2, (CUdeviceptr,), p.p)
end

end

include("cublas.jl")
include("cudnn.jl")
include("blob.jl")
include("backend.jl")
