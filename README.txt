RLS Business Parts Fix

Fixes two faults in the RLS Career Overhaul business computer (seen in 2.8.0.1):

1. A part can't be removed if it has a core slot under it, such as a seat's occupant or a muffler's
   tips. The cart shows "Core parts cannot be removed from this vehicle." Now only the parts you
   chose to remove are checked, so a part in a core slot itself is still protected.

2. Numbered cargo slots store their name as a translation table, which should break sorting in the
   All Parts list and its search. So the boxes can't be reached. The name now becomes plain text.

Not fixed: the Cargo Parts list still has no Remove button, because that filter is inside an RLS
.vue file. Use All Parts instead.

How it works: the mod wraps RLS functions at runtime and ships no RLS code, so it doesn't overwrite
RLS files or pin RLS to one version. If a later RLS version renames these functions, the mod logs a
warning under "xRlsBusinessParts" and changes nothing. Remove it once RLS fixes these itself.

Test, from this folder, with the paths inside the RLS zip extracted to <rls folder>:
  luajit tools/test.lua <rls folder>

Build: python tools/build.py

Licence: GNU AGPL 3.0 (see LICENSE). This mod is for BeamNG.drive and runs alongside RLS Career
Overhaul (https://github.com/RLS-Modding/rls_career_overhaul), which has its own licence. This mod
is not made or endorsed by RLS Modding.
