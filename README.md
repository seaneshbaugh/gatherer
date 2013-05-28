# Gatherer
Scrapes [gatherer.wizards.com](http://gatherer.wizards.com/Pages/Default.aspx) for MTG sets and cards. Outputs the results as SQL files; one for the list of sets and then one for each set.

## Usage
    $ ruby gatherer.rb [options]

## Options
```
-f, [--force]                # Ignore file collisions
-o, [--only-sets]            # Only download set info
-s, [--sets=SETS]            # Comma delimited list of sets to retrieve
-S, [--skip]                 # Skip file collisions

-p, [--pretend]              # Run but do not output any files
-q, [--quiet]                # Supress status output
-V, [--verbose]              # Show extra output
-y, [--pry]                  # Pry after completing

-h, [--help]                 # Show this help message and quit
-v, [--version]              # Show gatherer.rb version number and quit
```

## Examples
    $ ruby gatherer.rb
This retrieves all MTG sets.

    $ ruby gatherer.rb -s "Alliances,Future Sight"
This retrieves the "Alliances" and "Future Sight" sets.

    $ ruby gatherer.rb -oy
This retrieves only the sets (no cards) and then opens a Pry debug session.
