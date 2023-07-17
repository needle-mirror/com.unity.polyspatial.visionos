Notes about building and running on Mac:

- If you do NOT have a specific version of RealityKit that you need to run against:
    - If doing Build & Run, everything should just work.
    - If building an Xcode project, you need to manually:
        - right-click the PlugIns folder in Xcode, select Add Existing Files, select PolySpatial-macOS.bundle
        - open the project configuration (click the top xcode project node in the left sidebar), click on the app product, click on Build Phases, and expand out "Copy Plugins Phase".  Click the + and select the PolySpatial-macOS.bundle you just added.
- If you DO have a specific version of RealityKit you need to run against:
    - Build & Run won't work (at least not without possibly specifying `DYLD_FRAMEWORK_PATH` in the environment before launching Unity)
    - Build an Xcode project, then manually:
        - edit the scheme, and in the Run options, add an Environment Variable called `DYLD_FRAMEWORK_PATH` set to the directory that contains your frameworks
        - either add the plugin bundle as above (in the "no specific RK" section), OR add the PolySpatialRealityKit xcode project and reference the plugin product directly from there.


Some notes about the xcode and RK plugin setup:

- modulemap seemed to need to be called `module.modulemap`, maybe because that's what it was at build time?  It also needs to have the identical set of include files as things were built with.

- If -exported_symbol is used in the link line (`-Wl,-exported_symbol,_Foo`), _this overrides any visibility attributes_.  This seems super dumb.  Building for the iOS simulator seems to set `-Wl,-exported_symbols,_il2cpp_*` to LDFLAGS on UnityFramework, so we have to be explicit about our 3 trampoline symbols (`SetPolySpatialNativeAPIImplementation`, `GetPolySpatialNativeAPI`, `StartRealityKitWindow`)

- libPolySpatial_x.a is linked to the swift app, but needs to be used from UnityFramework.  The SetPolySpatialNativeAPI / GetPolySpatialNativAPI dance allows for that forwarding

TODO:

1. Right now the plugin static libraries are linked via an explicit `-lPolySpatial_x` added to OTHER_LDFLAGS.  We should add the `.a` to the pbxproj and reference it that way.  This is easy(ish) on iOS, but on MacOS we don't have Unity's pbxproj manipulation infra.  So we need to copy those files in as well.

2. Figure out how the `module.modulemap` behaviour actually works.  We never reference the `module.modulemap` file directly, but apparently just adding the `includes` dir to a search path causes llvm/swift to find the modulemap, read it, and understand a PolySpatialRealityKit module

3. We should make `module.modulemap` list explicit files.  If we add anything else to `includes` then it will fail.

4. We should rename `module.modulemap` once we understand #1 to something like `PolySpatialRealityKit.modulemap`.

5. We should get rid of (almost) all the .h files -- in particular, there's no reason to export the unity graphics format header "publicly".

.
