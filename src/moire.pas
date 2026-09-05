library moire;

{$mode objfpc}{$H+}

{ Free Pascal library. src/main.c is the process entry so macOS Cocoa starts. }

uses
  moireentry;

{ Named RunMoire, not MoireEntry: a procedure named like this unit
  (`moireentry`) is parsed as a unit reference, not a call. }
exports
  RunMoire;

begin
end.
