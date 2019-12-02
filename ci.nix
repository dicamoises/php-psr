let
    deps = {
        monolog = {
            url = https://github.com/Seldaek/monolog.git;
            rev = "1.25.2";
            sha256 = "1aa1xbs96kgrbvaiz8n3gqn9n6a5h9ppcjhw03j3lbpn87xp3xpp";
        };
        stash = {
            url = https://github.com/tedious/Stash.git;
            rev = "v0.15.2";
            sha256 = "1i2mm957xa4pws7cq6ikrhglvd80xwm5f42d0l5a5n5v3rrngnqy";
        };
        psr7 = {
            url = https://github.com/guzzle/psr7.git;
            rev = "1.5.2";
            sha256 = "05dphxj8jbqmjn1bnqxc6f86dkh99jhl1dksa9kmg9zck8x1j3c9";
        };
        container = {
            url = https://github.com/thephpleague/container.git;
            rev = "3.2.2";
            sha256 = "0b982fkxk0n1rz3l6ir552jfh9psmiy4zhbx7j6s1jhpqxaal4la";
        };
        link-util = {
            url = https://github.com/php-fig/link-util.git;
            rev = "1.0.0";
            sha256 = "02jsfdli2qw03jmsic0r6hyj0nmci3hhib8cq7nld497wh5raizy";
        };
        psx-cache = {
            url = https://github.com/apioo/psx-cache.git;
            rev = "v1.0.2";
            sha256 = "18waigg59033xzi2iak7j6xkq4zgjplkfs809m55q6pgf3zfy28w";
        };
        dispatch = {
            url = https://github.com/equip/dispatch.git;
            rev = "2.0.0";
            sha256 = "0678vkajvsshq0vxy1z3i7ms3p6ig84y3gcw5hqhxxr3fy741aah";
        };
        request-handler = {
            url = https://github.com/middlewares/request-handler.git;
            rev = "v1.3.0";
            sha256 = "1njcxzvyjw2dnl6lgbr8rh1qydrfgq07pdgs9wpkbzr3mv2cgra8";
        };
        http-factory-guzzle = {
            url = https://github.com/http-interop/http-factory-guzzle.git;
            rev = "1.0.0";
            sha256 = "1p6r7pya2v57lls9im82pjkmvismp9kfym1c8xnvgigrncg2nz7h";
        };
        guzzle-psr18-adapter = {
            url = https://github.com/ricardofiorani/guzzle-psr18-adapter.git;
            rev = "v1.0.1";
            sha256 = "19nkbq0ri4182rwjvb9nm7jm08m9g3zh5aq629003zfa3q59x87c";
        };
        # @TODO run only on PHP >= 7.2
        #tukio = {
        #    url = https://github.com/Crell/Tukio.git;
        #    rev = "1.0.0";
        #    sha256 = "1r9676bh3y5rmb4w5bjnsz5s0b76v5w5rw4mr3v4swdnr3rbh4xk";
        #};
    };

    initComposerRepository = { name, pkgs, src, php, composer, git, cacert, ... }:
        pkgs.runCommand "psr-testrepo-${name}" {
            src = pkgs.fetchgit src;
            buildInputs = [ php composer git ];
            GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        } ''
            cp -r $src/* .
            composer install --no-interaction --no-ansi --no-progress --no-suggest --prefer-dist
            find vendor/psr/ -type f -not -iname "*test*" -delete
            mkdir -p $out
            cp -r ./* $out
        '';

    testComposerRepository = { name, pkgs, psr, php, composer, git, cacert, ... }@args:
        pkgs.runCommand "psr-testresults-${name}" {
            src = initComposerRepository args;
            buildInputs = [ php git ];
        } ''
            cp -r $src/* .
            ${php}/bin/php -d extension=${psr}/lib/php/extensions/psr.so ./vendor/bin/phpunit | tee $out
        '';

    generatePsrDrv = { pkgs, php }:
        pkgs.runCommand "pecl-psr.tgz" {
            buildInputs = [ php ];
            src = builtins.filterSource
                (path: type: baseNameOf path != ".idea" && baseNameOf path != ".git" && baseNameOf path != "ci.nix")
                ./.;
        } ''
            cp -r $src/* .
            pecl package | tee tmp.txt
            pecl_tgz=$(cat tmp.txt | grep -v Warning | awk '{print $2}')
            echo $pecl_tgz
            cp $pecl_tgz $out
        '';

    generatePsrTestsForPlatform = { pkgs, php, buildPecl, composer, phpPsrSrc }:
        let
            psr = pkgs.callPackage ./derivation.nix {
               inherit php buildPecl phpPsrSrc;
            };
        in pkgs.recurseIntoAttrs ({
            inherit psr;
        } // builtins.mapAttrs (name: v: testComposerRepository {
          inherit pkgs psr php composer name;
          inherit (pkgs) git cacert;
          src = v;
        }) deps);
in
builtins.mapAttrs (k: _v:
  let
    path = builtins.fetchTarball {
       url = https://github.com/NixOS/nixpkgs/archive/release-19.09.tar.gz;
       name = "nixpkgs-19.09";
    };
    pkgs = import (path) { system = k; };

    phpPsrSrc = generatePsrDrv {
        inherit pkgs;
        inherit (pkgs) php;
    };
  in
  pkgs.recurseIntoAttrs {
    php71 = let
        path = builtins.fetchTarball {
           url = https://github.com/NixOS/nixpkgs/archive/release-19.03.tar.gz;
           name = "nixpkgs-19.03";
        };
        pkgs = import (path) { system = k; };
        php = pkgs.php71;
    in generatePsrTestsForPlatform {
        inherit pkgs php phpPsrSrc;
        composer = pkgs.php71Packages.composer;
        buildPecl = pkgs.callPackage "${path}/pkgs/build-support/build-pecl.nix" { inherit php; };
    };

    php72 = let
        php = pkgs.php72;
    in generatePsrTestsForPlatform {
        inherit pkgs php phpPsrSrc;
        composer = pkgs.php72Packages.composer;
        buildPecl = pkgs.callPackage "${path}/pkgs/build-support/build-pecl.nix" { inherit php; };
    };

    php73 = let
        php = pkgs.php73;
    in generatePsrTestsForPlatform {
        inherit pkgs php phpPsrSrc;
        composer = pkgs.php73Packages.composer;
        buildPecl = pkgs.callPackage "${path}/pkgs/build-support/build-pecl.nix" { inherit php; };
    };

    php = let
        path = builtins.fetchTarball {
           url = https://github.com/NixOS/nixpkgs/archive/master.tar.gz;
           name = "nixpkgs-unstable";
        };
        pkgs = import (path) { system = k; };
        php = pkgs.php;
    in generatePsrTestsForPlatform {
        inherit pkgs php phpPsrSrc;
        composer = pkgs.phpPackages.composer;
        buildPecl = pkgs.callPackage "${path}/pkgs/build-support/build-pecl.nix" { inherit php; };
    };
  }
) {
  x86_64-linux = {};
  # Uncomment to test build on macOS too
  # x86_64-darwin = {};
}