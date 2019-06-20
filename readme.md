# Crütech Scripts #

A repo of scripts for Crütech!

## Scripts ##
Currently included scripts can be found in the `bin` directory of this project.
These scripts are:
  * `user_namer.pl` for generating adduser compatible lists.
  * `newusers-fix.pl` for calling newusers command safely.
  * `setup-users.pl` for filling in users home directories.
    * `add-template-to-homes.pl` for adding templated files.
    * `setup-on-login-hooks.pl` for installing .profile scripts to users.
  * `find-user-files.pl` for collecting and archiving and user files after camp.
  * `clean-users.pl` for cleaning up users after a camp.

to call these scripts, run them from the project root:
`bin/<script-name>.pl [options]`
All scripts implement a --help option documentation can be retrieved with:
`perldoc <script-name>`

or via
`bin/<script-name>.pl --man`

All of the scripts are written in Perl5 and only utilise core modules (however many linux distros interpret that defenition liberaly). As such any system perl should be able to execute these scripts without any additional packages. In the case where this is not so (A system with an incomplete core library) you may consult the `cpanfile` for a complete list of modules used (and use `cpanm --sudo --installdeps .` to bring everything up to date).
If you are having further issues with dependencies it may be worth looking into plenv to setup an independent perl build to your system perl, any perl version newer than 5.10.0 should work.

## User names ##
All scripts utilise a core definition as to what a camp user name is. This pattern is defined in `lib/Crutech/Utils` in the `ltsp_users` subroutine.
The current definition is that a camper user name ends with: 1 or more numbers optionally followed by alphabetic or numeric characters.
for example:
  * 'Neo' would not be considered a camp user name.
  * 'Nemo1' would be considered a camp user name.
  * 'buzz88l' would asl be a camper user name

The above assumption is intended to permeate the entire suite of scripts.
