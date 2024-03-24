# Moving_Virtual_Background
The project connects a PTZ usb camera and a browser source via an OBS lua script.

This version is MacOS only.  The same idea could be done in windows.  

An example use is creating a moving virtual background by sending the PTZ data to the Photo Sphere Viewer Javascript library.  


### Repositories 

[Photo Sphere Viewer](https://photo-sphere-viewer.js.org/)

[USB Video Capture (UVC) Utility for Mac](https://github.com/jtfrey/uvc-util)

[OBS Lua Script to run UVC commands](https://github.com/marklagendijk/obs-scene-execute-command-script)

```mermaid
stateDiagram
    direction LR
    A: USB PTZ Camera
    B: OBS
    a: uvc util
    b: lua Script
    c: browser
    d: Text Source
    [*] --> B
    
    B --> [*]
    state B {
      direction LR
    A --> a
      a --> b
      b --> c
      b --> d 
    }
```
