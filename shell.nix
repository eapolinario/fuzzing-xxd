{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  # Development shell for fuzzing-xxd
  # Provides the radamsa binary used by the diff_fuzz target
  buildInputs = [
    pkgs.radamsa
  ];
}