# VAmpNL

----
## What?

Virtual Amp Non-Linearity.

This is an Ardour5 plugin for simulating the central part of guitar amps.

It was implemented according to [Block-oriented modeling of distortion audio effects using iterative minimization](https://www.ntnu.edu/documents/1001201110/1266017954/DAFx-15_submission_21.pdf) by Felix Eichas, Stephan Möller and Udo Zölzer

The effect block has to be inserted between two EQs. All parameters (including those of the EQs) can be found algorithmically in order to simulate real amps with close to undistinguishable resemblance, see [all this research stuff](https://www.hsu-hh.de/ant/eichas). However, feel free to try to hand-tune.

----
## Installation

Copy vampnl.lua into your Ardour5 script folder.

* GNU/Linux: $HOME/.config/ardour5/scripts
* Mac OS X: $HOME/Library/Preferences/Ardour5/scripts
* Windows: %localappdata%\ardour5\scripts

Then open Ardour, right-click on the effects stack of your track, New Plugin > By Creator > mqnc > VAmpNL (Lua)

Double-click the effect for tweaking parameters, shift-double-click for inline display of the input output curve.

----
## Thanks

Props and kudos to Felix and his homies!
