add_library(videometal
  MRCHelpers.h
  MTLBoundingBox.mm
  MTLBoundingBox.h
  MTLGfx.mm
  MTLGfx.h
  MTLMain.mm
  MTLObjectCache.h
  MTLObjectCache.mm
  MTLPerfQuery.mm
  MTLPerfQuery.h
  MTLPipeline.mm
  MTLPipeline.h
  MTLShader.mm
  MTLShader.h
  MTLStateTracker.mm
  MTLStateTracker.h
  MTLTexture.mm
  MTLTexture.h
  MTLUtil.mm
  MTLUtil.h
  MTLVertexFormat.mm
  MTLVertexFormat.h
  MTLVertexManager.mm
  MTLVertexManager.h
  VideoBackend.h
)

find_library(METAL_LIBRARY Metal)
find_library(QUARTZCORE_LIBRARY QuartzCore)

target_link_libraries(videometal
PUBLIC
  common
  videocommon
PRIVATE
  spirv_cross
  ${FOUNDATION_LIBRARY}
  ${METAL_LIBRARY}
  ${QUARTZCORE_LIBRARY}
)

if(IOS)
  find_library(METALFX_LIBRARY MetalFX)
  if(METALFX_LIBRARY)
    target_link_libraries(videometal PRIVATE ${METALFX_LIBRARY})
  endif()
  find_library(COREVIDEO_LIBRARY CoreVideo)
  if(COREVIDEO_LIBRARY)
    target_link_libraries(videometal PRIVATE ${COREVIDEO_LIBRARY})
  endif()
  find_library(COREGRAPHICS_LIBRARY CoreGraphics)
  if(COREGRAPHICS_LIBRARY)
    target_link_libraries(videometal PRIVATE ${COREGRAPHICS_LIBRARY})
  endif()
endif()

target_compile_options(videometal PRIVATE -fno-objc-arc)
