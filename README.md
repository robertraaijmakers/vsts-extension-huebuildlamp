# Release Notes
> **14-6-2016**

> - First launch

# Description
The VSTS Hue Build Lamp task helps you to create insight in the status of the build via lights.

Additional features include:
 * Create additional Recipes via IFTTT (e.g. play sound via Spotify on speakers when the build breaks)

# Documentation
Please check the [Wiki](https://github.com/robertraaijmakers/vsts-extension-huebuildlamp/wiki).

If you have ideas or improvements to existing tasks, don't hestitate to leave feedback or [file an issue](https://github.com/robertraaijmakers/vsts-extension-huebuildlamp/issues).

# Considerations
This is the first version of the script and works via IFTTT and a SMTP server to control the lights. While IFTTT gives a lot of possibilities we want to control the lights directly from the extension. For Philips Hue there is no API available (yet), that's why I chose to control the lights via IFTTT. The disadvantage for now is that it toggles all the lights attached to the Hue Bridge.

You need to create an IFTTT account and have access to an SMTP login (e.g. your office365 account, outlook etc.)
