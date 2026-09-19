program moire;

{$mode objfpc}{$H+}

{ Windows / Linux process entry. macOS still uses src/main.c + libmoire
  because Homebrew SDL needs a C main. Here fpc can emit moire.exe itself. }

uses
  moireentry;

begin
  RunMoire(argc, argv);
end.
