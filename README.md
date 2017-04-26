# bluenet-ios-guidestone-config

### Configurator based on Bluenet lib ios

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

# Getting started

The bluenet-ios-guidestone-config uses Carthage to handle it's dependencies. It's also the way you install Bluenet ios in other projects.
If you're unfamiliar with Carthage, take a look at the project here: https://github.com/Carthage/Carthage

To get the bluenet-ios-guidestone-config up and running, first you need to have Carthage installed. Then navigate to the project dir in which you want to include Bluenet-ios-lib and create a cartfile if one did not exist yet.
(a cartfile is just a file, called "Cartfile" without extensions. Edit it in a text editor or XCode).

To add the dependency to the Cartfile, copy paste the lines below into it, save it and close it:

```
# BluenetLib
github "crownstone/bluenet-lib-ios"
```

Once this is finished, run the following command in your terminal (in the same folder as the Cartfile)

```
carthage bootstrap --platform iOS --no-use-binaries
```

All dependencies will then be downloaded, built and placed in a Carthage/Build folder. You then drag the frameworks into your XCode project and you're good to go!
