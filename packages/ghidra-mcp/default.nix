{
  lib,
  stdenv,
  fetchFromGitHub,
  maven,
  unzip,
  ghidra,
  python3Packages,
  makeWrapper,
}: let
  pname = "ghidra-mcp";
  version = "1.4";

  src = fetchFromGitHub {
    owner = "LaurieWired";
    repo = "GhidraMCP";
    tag = version;
    hash = "sha256-9NzmYQqfvQm5wjmmPWOG1+g9zCzGrUrRZX+m1nRS0m4=";
  };

  # Symlink Ghidra JARs into lib/ for system-scoped Maven dependencies.
  # These correspond to the <systemPath> entries in the upstream pom.xml.
  symlinkGhidraJars = ''
    mkdir -p lib
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Framework/Generic/lib/Generic.jar lib/Generic.jar
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Framework/SoftwareModeling/lib/SoftwareModeling.jar lib/SoftwareModeling.jar
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Framework/Project/lib/Project.jar lib/Project.jar
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Framework/Docking/lib/Docking.jar lib/Docking.jar
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Features/Decompiler/lib/Decompiler.jar lib/Decompiler.jar
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Framework/Utility/lib/Utility.jar lib/Utility.jar
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Features/Base/lib/Base.jar lib/Base.jar
    ln -sf ${ghidra}/lib/ghidra/Ghidra/Framework/Gui/lib/Gui.jar lib/Gui.jar
  '';

  # The Ghidra extension component (built from source with Maven)
  extension = maven.buildMavenPackage {
    pname = "${pname}-extension";
    inherit version src;

    mvnHash = "sha256-QBDyNI/srppFoHjvT6GUNAGAq1rO5f+0YVYsy1AMT8w=";

    nativeBuildInputs = [unzip];

    mvnFetchExtraArgs = {
      preBuild = symlinkGhidraJars;
    };

    preBuild = symlinkGhidraJars;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/ghidra/Ghidra/Extensions
      # Artifact version is defined in the upstream pom.xml, not the Nix version.
      unzip target/GhidraMCP-1.0-SNAPSHOT.zip -d $out/lib/ghidra/Ghidra/Extensions/

      # Prevent attempted creation of plugin lock files in the Nix store
      touch $out/lib/ghidra/Ghidra/Extensions/GhidraMCP/.dbDirLock

      runHook postInstall
    '';

    meta = {
      description = "Ghidra extension that exposes program data via HTTP server for MCP integration";
      homepage = "https://github.com/LaurieWired/GhidraMCP";
      license = lib.licenses.asl20;
      platforms = lib.platforms.all;
    };
  };

  # Python dependencies for the MCP bridge
  pythonEnv = python3Packages.python.withPackages (ps: [
    ps.requests
    ps.mcp
  ]);
in
  # The MCP bridge (main package)
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [makeWrapper];

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib

      # Install the bridge script
      cp bridge_mcp_ghidra.py $out/lib/

      # Create wrapper with Python environment
      makeWrapper ${pythonEnv}/bin/python $out/bin/ghidra-mcp \
        --add-flags "$out/lib/bridge_mcp_ghidra.py"

      runHook postInstall
    '';

    passthru = {
      inherit extension;
    };

    meta = {
      description = "MCP server for allowing LLMs to autonomously reverse engineer applications with Ghidra";
      homepage = "https://github.com/LaurieWired/GhidraMCP";
      license = lib.licenses.asl20;
      mainProgram = "ghidra-mcp";
      platforms = lib.platforms.all;
    };
  }
