{ config, lib, pkgs, utils, ... }:

with utils;
with lib;

let

  cfg = config.vpsadmin.core.node;

  allSslOptions = {
    certfile = "string";
    keyfile = "string";
    cacertfile = "string";
    password = "string";
    reuse_sessions = "bool";
    secure_renegotiate = "bool";
    fail_if_no_peer_cert = "bool";
    verify = "atom";
  };

  nixValueToErlang = name: value:
    let
      convert = {
        "bool" = v: if v then "true" else "false";
        "string" = v: "\"${v}\"";
        "atom" = v: toString v;
      };
    in convert.${allSslOptions.${name}} value;

  sslOptions = attrs: concatStringsSep ",\n" (mapAttrsToList (k: v:
    "{${k}, ${nixValueToErlang k v}}"
  ) attrs);

  usedOptions = opts: filterAttrs (k: v: v != null) opts;

  sslConfig = pkgs.writeText "ssl_dist_optfile" ''
    [
      {server, [
        ${sslOptions (usedOptions cfg.ssl.config.server)}
      ]},
      {client, [
        ${sslOptions (usedOptions cfg.ssl.config.client)}
      ]}
    ].
  '';

  vmArgs = pkgs.writeText "vm.args" ''
    -name vpsadmin@${cfg.hostName}
    -setcookie ${cfg.cookie}

    ${optionalString cfg.ssl.enable ''
    -proto_dist inet_tls
    -ssl_dist_optfile ${sslConfig}
    ''}
  '';

  appConfig = pkgs.writeText "config.exs" ''
    use Mix.Config

    config :vpsadmin_base, :nodectld_socket, "/var/run/vpsadmind.sock"

    config :vpsadmin_queue, :queues, [
      {:default, 4}
    ]

    config :vpsadmin_transactional, :supervisor_node, :"${cfg.supervisorNode}"
  '';

  coreNode = pkgs.vpsadmin.core.node {
    releaseConfig = pkgs.writeText "rel-config.exs" ''
      environment :node do
        set include_erts: true
        set include_src: false
        set vm_args: "${vmArgs}"
        set config_providers: [
          {Mix.Releases.Config.Providers.Elixir, ["''${RELEASE_ROOT_DIR}/etc/config.exs"]}
        ]
        set overlays: [
          {:copy, "${appConfig}", "etc/config.exs"}
        ]
      end

      release :node do
        set version: current_version(:vpsadmin_base)
        set applications: [
          ${optionalString cfg.ssl.enable ":ssl,"}
          :runtime_tools,
          :vpsadmin_base,
          :vpsadmin_queue,
          :vpsadmin_transactional,
          :vpsadmin_worker,
          :vpsadmin_node
        ]
      end
    '';
    releaseName = "node";
    releaseEnv = "node";
  };

  initScript = pkgs.substituteAll {
    name = "core-node.init";
    src = ./initscript.sh;
    isExecutable = true;
    node = toString coreNode;
    rsync = toString pkgs.rsync;
  };

  activationScript = pkgs.substituteAll {
    name = "core-node.activate";
    src = ./activate.sh;
    isExecutable = true;
    inherit initScript;
  };

  builder = pkgs.runCommand "vpsadmin-core-node-${cfg.hostName}" {} ''
    mkdir $out
    ln -sf ${coreNode} $out/node
    ln -sf ${activationScript} $out/activate
    ln -sf ${initScript} $out/initscript.sh
  '';

  mkSslOption = name:
    let
      type = allSslOptions.${name};
      fn = {
        string = { type = types.nullOr types.str; };
        bool = { type = types.nullOr types.bool; };
        atom = { type = types.nullOr types.str; };
      };
    in nameValuePair name (mkOption ({ default = null; } // fn.${type}));

  mkSslOptions = names: listToAttrs (map mkSslOption names);

  mkCommonSslOptions = mkSslOptions [
    "certfile" "keyfile" "cacertfile" "password" "reuse_sessions"
    "secure_renegotiate" "verify"
  ];

  mkServerSslOptions = mkCommonSslOptions // (mkSslOptions [
    "fail_if_no_peer_cert"
  ]);

  mkClientSslOptions = mkCommonSslOptions;

in

{

  ###### interface

  options = {
    vpsadmin.core.node = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable vpsAdmin integration, i.e. include nodectld and nodectl
        '';
      };

      hostName = mkOption {
        type = types.str;
        description = ''
          FQDN.
        '';
      };

      cookie = mkOption {
        type = types.str;
        description = ''
          Cookie for Erlang VM. Has to be set to the same value on all nodes
          within the cluster.
        '';
      };

      supervisorNode = mkOption {
        type = types.str;
        description = ''
          Long name of the supervisor node.
        '';
      };

      ssl = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable SSL ccomunication between cluster nodes.

            SSL configuration is passed to <literal>erl</literal> as a part of
            <literal>-ssl_dist_optfile</literal> config.
            See http://erlang.org/doc/apps/ssl/ssl_distribution.html for
            more information.
          '';
        };

        config = {
          server = mkServerSslOptions;
          client = mkClientSslOptions;
        };
      };
    };
  };

  ###### implementation

  config = mkMerge [
    (mkIf cfg.enable {
      system.build.core-node = builder;
    })
  ];
}
