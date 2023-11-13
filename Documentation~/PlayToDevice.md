---
uid: psl-play-to-device
---

# Play to Device
The Play to Device feature drastically improves iteration and debugging workflows. it enables you to:

* Efficiently iterate and live preview your content across the Unity editor on the visionOS simulator or the Apple Vision Pro device
* Deploy your content without rebuilding an Xcode project
* Access Unity editor’s play mode features on the visionOS simulator and Apple Vision Pro device

This feature is delivered through the Play to Device Host application, which can be installed on the visionOS Simulator or an Apple Vision Pro device. With the Play to Device host running, you can press Play in the Unity Editor and see your content appear in the simulator or on device, rendered by RealityKit. No intermediate builds are required.

 Any changes you make in Unity Editor - such as creating game objects, modifying inspector values, updating and recompiling shader graphs, etc. - will be synchronized to the simulator/device in real time, and any interactions you perform on the host will be synchronized back to the editor.

**NOTE**: Loading a scene during runtime is currently not supported on Play to Device.

## Version Compatibility Matrix

The Play to Device Host must match your PolySpatial package version exactly. The table below provides links to the Xcode and device-specific hosts compatible with each PolySpatial release. 

<table>
  <tr>
   <td><strong>PolySpatial Version</strong>
   </td>
   <td>Supported Unity Versions
   </td>
   <td>Required Xcode Versions
   </td>
   <td>Required Firmware Version
   </td>
   <td>Xcode .App Link (Apple Silicon)
   </td>
   <td>Device TestFlight Link
   </td>
  </tr>
  <tr>
   <td>0.6.0
   </td>
   <td>2022.3.11f1 and higher
   </td>
   <td>Xcode 15.1 Beta 1 and higher 
   </td>
   <td>visionOS beta 4 (21N5259k) and higher
   </td>
   <td><a href="https://drive.google.com/drive/u/0/folders/11Ffgx3aZ-Hqx2mk2MtFb56c-q7b0ex88">Link</a> 
   </td>
   <td><a href="https://testflight.apple.com/join/FVMH8aiG">Link</a> 
   </td>
  </tr>
</table>

## First Time Setup - visionOS Simulator
To install the host app for the visionOS simulator:

1. Download the “**Play To Device Host.app.zip**” to your Apple Silicon Mac. See the Compatibility Matrix above to identify the right version given your PolySpatial version. 
2. Extract the zip file revealing “**Play To Device Host.app**” in Finder.
3. Start the visionOS simulator, either by going to **“Xcode > Open Developer Tool > Simulator**” within Xcode, or using Spotlight (command+space) and typing “simulator”.
4. When the simulator is running, you can see the home screen with various app icons. Drag “**Play To Device Host.app**” from the Finder window into the simulator window.
5. After a few seconds, you should see “**Play To Device Hos**t” appear as one of the app icons on the home screen. Note that you may have to scroll the app list to see it.


## First Time Setup - visionOS Hardware
To install the host app for an Apple Vision Pro device:

1. Follow the TestFlight invite link on your computer or smartphone (or in Safari on the device). You should see an invite code. See the **Compatibility Matrix** above to access a link compatible with your PolySpatial version. 
2. Open the TestFlight app on your Vision Pro device, signing into your Apple account if necessary.
3. Tap “**Redeem Code**” in the TestFlight app.
4. Enter the code you saw in your browser after following the invite link.
5. Tap “**Download**” in the TestFlight app after reading the build information and release notes.
6. After a few seconds, either tap “**Open**” from TestFlight or navigate to the Play To Device Host application that now appears on your home screen.


## First Time Setup - Unity Editor
Once you've installed a host app for device or simulator (see above):

1. Make sure the host and development machine are on the same LAN.
2. Launch the host app. 
3. In Unity Editor, open the Play to Device Editor window by clicking on  \
**Window > PolySpatial > Play to Device**
4. Copy the IP address displayed within the Host app to the **“Host IP**” field of the Play to Device editor window.
5. Enable **Connect to Player on Play Mode**
6. Enter **Play mode** in the Unity Editor. The Unity Editor will connect to the host and begin streaming your experience to the host in real time. You can then view, play, or interact with your experience via either editor or device; changes and interactions will automatically stay in sync. 

If you notice that your connection is timing out, you can increase the connection timeout in the Play To Device Editor Window. The default timeout is 5 seconds.

![Play To Device Window](images/PlayToDevice/PlayToDeviceWindow.png)

## Subsequent Usage

After initial setup, your content will be synced to the host app each time you press play, as long as **Connect to Player on Play Mode** is enabled and the host remains live. 

## Troubleshooting
For troubleshooting issues refer to the [Play to Device troubleshooting section in the FAQ](FAQ.md#play-to-device-host)

# Tutorial: Previewing a cube

To preview an application in the Play To Device host:

1. Create a new volume camera configuration asset by right clicking in the project view and selecting **Create > PolySpatial > Volume Camera Configuration**.

![VolCamConfig](images/PlayToDevice/1.CreateVolumeCameraConfiguration.png)

**Note:** Make sure the `Volume Camera Configuration` asset is in the `Resources` folder.
2. Set the created volume camera configuration _mode_ to `Bounded`

![VolVamConfigMode](images/PlayToDevice/2.SetVolumeCameraConfigurationMode.png)

3. On a new empty scene create an Empty game Object, add a volume camera component to it and set the Volume camera configuration to the one just created.

![VolCamSetup](images/PlayToDevice/3.VolumeCameraSetup.gif)

4. Create a small cube in the scene and place it inside the volume camera bounds.

![CubeSetup](images/PlayToDevice/4.CreateContentInsideVolumeCamera.gif)

5. Open the Play To Device host in either the visionOS Simulator or a Vision Pro device.

![PlayToDeviceApp](images/PlayToDevice/5.PlayToDeviceSimulator.png)

6. Open the Play To Device _Editor Window_ and make sure **Connect To Player On Play Mode** is toggled on. To no longer stream to the Play To Device and return to Game View, simply turn off the **Connect To Player On Play Mode** property in the Play To Device Editor Window.

7. With the Play To Device host open, click the Play button in the Editor. The application should begin running both within the editor and in the host app.

![PlayToDeviceStream](images/PlayToDevice/6.PlayToDeviceStream.gif)

