# verbosity.bash

Library to enhance verbosity management in bash scripts.
In short, can:
- scan the command line for verbosity option
- mute every output sent to standard
- add one or more verbosity level

## Basic usage

```bash
source verbosity.sh

declare -r VERBOSE="${VERBOSITY_FD[2]}" # optional

echo "This is displayed in standard and verbose mode"
echo "This is only displayed in verbose mode" >&"${VERBOSE}"
echo "This is an error message. Always displayed" >&2
```

This will:
* Search for `-v`, `--verbose`, `-q`, `--quiet` option in your script's command
line. Whichever comes last.
* if `-v` or `--verbose` is detected, then all output sent to `VERBOSE_FD[2]`
will be be displayed to standard output.
* if `-q` or `--quiet` is detected, then all output sent to standard will be
ignored

## Use your own verbosity level(s)

### Adding a verbosity level

You may want to add a debug mode or other verbosity level.
`verbosity::add_level_definition level [cli_option ...]` is here to the rescue.

```bash
source verbosity.sh

# add your own levels. See function's documentation
verbosity::add_level_definition 3 "-d" "--debug"

# you need to call this function to parse command line option.
verbosity::from_command_line "$@"
# or, you can set the verbosity level manually
verbosity::set_current_level 3


# using your newly created verbosity level

echo "This will be displayed in verbose and debug mode." >&"${VERBOSITY_FD[2]}"
echo "This will only be displayed in debug mode." >&"${VERBOSITY_FD[3]}"
```

### Removing predefined verbosity level

By default, this lib comes with two levels:

- 0, quiet mode. Corresponding to command line option `-q` and `--quiet`
- 2, verbose mode. Corresponding to command line option `-v` and `--verbose`

You can remove these levels by setting the `VERBOSITY_CUSTOM` to `true` when
importing the lib.

```bash
VERBOSITY_CUSTOM=true source verbosity.sh

# add your own levels. These are the default ones. See function's documentation
verbosity::add_level_definition 0 "-q" "--quiet"
verbosity::add_level_definition 2 "-v" "--verbose"

# you need to call this function to parse command line option.
verbosity::from_command_line "$@"
# or, you can set the verbosity level manually
verbosity::set_current_level 2
```

## Caveats

### sourcing the lib inside a function

The default behavior of the lib is to parse command line options when you source
it.
If you source the lib inside a function and don't propagate command line options
it won't work.

```bash
function main
{
    source verbosity.sh

    # ...
}

main
```

You might want to set command line options when sourcing the lib:

```bash
function main
{
    # pass command line options
    source verbosity.sh "$@"

    # ...
}

# pass command line options to the function
main "$@"
```

or, later, by calling manually
`verbosity::from_command_line [command_line_option ...]`


```bash
function main
{
    source verbosity.sh

    # ...

    # pass command line options
    verbosity::from_command_line "$@"
}

# pass command line options to the function
main "$@"
```

