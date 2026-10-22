{
  stdenv,
  typst,
  ...
}:
stdenv.mkDerivation {
  pname = "blinkasm_report";
  version = "0.0.1";
  src = ../report;
  nativeBuildInputs = [ typst ];
  buildPhase = ''
    runHook preBuild
    typst compile report.typ report.pdf
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm644 report.pdf "$out/blinkasm_report.pdf"
    runHook postInstall
  '';
}
