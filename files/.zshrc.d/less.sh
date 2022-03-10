# -F or --quit-if-one-screen
#
#     Causes less to automatically exit if the entire file can be
#     displayed on the first screen.
#
#
# -M or --LONG-PROMPT
#
#     Causes less to prompt even more verbosely than more.
#
#
# -Q or --QUIET or --SILENT
#
#     Causes moderately "quiet" operation: the terminal bell is not
#     rung if an attempt is made to scroll past the end of the file or
#     before the beginning of the file. If the terminal has a "visual
#     bell", it is used instead. The bell will be rung on certain
#     other errors, such as typing an invalid character. The default
#     is to ring the terminal bell in all such cases.
#
#
# -R or --RAW-CONTROL-CHARS
#
#     Like -r, but only ANSI "color" escape sequences are output in
#     "raw" form. Unlike -r, the screen appearance is maintained
#     correctly in most cases.
#
#     -r or --raw-control-chars causes "raw" control characters to be
#     displayed. The default is to display control characters using the
#     caret notation; for example, a control-A (octal 001) is displayed
#     as "^A".
#
#
# -X or --no-init
#
#     Disables sending the termcap initialization and deinitialization strings to the terminal.
#     This is sometimes desirable if the deinitialization string does something unnecessary, like
#     clearing the screen.
#
#
# -xn,... or --tabs=n,...
#
#     Sets tab stops. If only one n is specified, tab stops are set at
#     multiples of n. If multiple values separated by commas are
#     specified, tab stops are set at those positions, and then
#     continue with the same spacing as the last two. For example,
#     -x9,17 will set tabs at positions 9, 17, 25, 33, etc. The default
#     for n is 8.

export LESS='FMQRXx4'
