---
uid: psl-vos-webcam-textures
---
# PolySpatial WebCamTexture Support
PolySpatial transfers WebCamTextures to host platforms using an optimized path.  On visionOS, this is performed by using a GPU blit to copy the contents of the WebCamTexture to a texture provided by RealityKit.  Transferring large numbers of WebCamTextures at once and/or WebCamTextures with large dimensions may still incur a performance penalty, however.

By default, Unity does not enable WebCamTexture support. You must create a scripting define named `POLYSPATIAL_ENABLE_WEBCAM` to use, and make sure that you fill out the `Camera Usage Description` field in `Player Settings > Other settings`. If you don't do this, then you will see errors with `LocalAssetManager` as it doesn't know how to deal with asset types it doesn't know about.

## Platform Support
Support for WebCamTextures is dependent on the underlying API support on the target platform. This support may vary and might be entirely missing so take care to validate your needs on the platforms you wish to run on.

## Texture updates and manual dirtying
WebCamTextures are not auto dirtied when the camera updates the texture. This means that PolySpatial will not know that it needs to update the texture on the target host platform unless told. You can do this by using the `Unity.PolySpatial.PolySpatialObjectUtils.MarkDirty(webCamTexture)` on every frame (Usually in Update) in which the WebCamTexture is being changed while playing.

```
using UnityEngine;
using Unity.PolySpatial;

public class SetWebCamDirty : MonoBehaviour
{
#if POLYSPATIAL_ENABLE_WEBCAM    
    public WebCamTexture texture;
#endif

    void Update()
    {
#if POLYSPATIAL_ENABLE_WEBCAM        
        // Texture may be null if the web camera isn't actively recording
        // into it.
        if (texture != null &&  texture.isPlaying)
            Unity.PolySpatial.PolySpatialObjectUtils.MarkDirty(texture);
#endif            
    }
}
```

This dirtying API, as with all if the WebCamTextureSupport, is on available when `POLYSPATIAL_ENABLE_WEBCAM` is defined.


