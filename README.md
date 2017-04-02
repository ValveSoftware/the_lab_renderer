# Community Version of "The Lab Renderer"
## Currently searching for maintainers!
Valve’s VR renderer used in The Lab (Valve’s VR launch title for the HTC Vive)

This is the set of scripts and shaders that drove rendering in The Lab. It is a forward renderer with support for up to 18 dynamic shadowing lights in a single pass with MSAA enabled, and it included the Adaptive Quality system that dynamically adjusts rendering resolution to maintain framerate in VR. 

Requires Unity 5.4.b15 or newer.

## More information:
http://steamcommunity.com/games/250820/announcements/detail/604985915045842668

## Goals:
1) Provide support for the Lab Renderer in current and future Unity versions
2) Increase the supported features

## Contribution:
We don't have many contribution requirements, but we do ask that all version compatability fixes be wrapped in branching version logic. For example, if you need to fix something that is broken only in version 5.5.X of Unity, do this:
```
#if UNITY_5_5
<unity 5.5 code here>
#else
<old code here>
#endif
```

