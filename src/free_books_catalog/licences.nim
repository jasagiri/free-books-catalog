## Which licences let a consumer use a source commercially (FBC-10). A consumer that sets
## `"commercialOnly": true` gets a catalog in which every source states at least one licence and
## every stated licence is on this list; catalog_build refuses to write any other.
##
## On the list: SPDX identifiers of licences that allow use, copying, modification and
## distribution for any purpose, commercial use included. Left off: non-commercial (NC) and
## no-derivatives (ND) licences, and sources that state no licence.

import std/sets
import ./model

const commercialLicenses* = [
  "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "BSD-4-Clause", "ISC", "MIT", "MPL-2.0",
  "CC0-1.0", "Unlicense",
  "CC-BY-2.0", "CC-BY-2.5", "CC-BY-3.0", "CC-BY-4.0",
  "CC-BY-SA-2.0", "CC-BY-SA-2.5", "CC-BY-SA-3.0", "CC-BY-SA-4.0",
  "GPL-2.0-only", "GPL-2.0-or-later", "GPL-3.0-only", "GPL-3.0-or-later",
  "LGPL-2.0-only", "LGPL-2.0-or-later", "LGPL-2.1-only", "LGPL-2.1-or-later",
  "LGPL-3.0-only", "LGPL-3.0-or-later",
  "GFDL-1.3-only", "GFDL-1.3-or-later", "GFDL-1.3-no-invariants-only",
  "GFDL-1.3-no-invariants-or-later",
  "Linux-man-pages-copyleft", "Vixie-Cron", "lsof"]

func licenceErrors*(sources: openArray[Source]): seq[string] {.raises: [].} =
  ## One line per source that states no licence or a licence off the list, naming the source and
  ## the licence. Empty when every source may be used commercially.
  let allowed = commercialLicenses.toHashSet
  for s in sources:
    if s.licenses.len == 0:
      result.add $s.id & " " & s.url & ": states no licence"
    for l in s.licenses:
      if l notin allowed:
        result.add $s.id & " " & s.url & ": licence " & l & " does not allow commercial use"
