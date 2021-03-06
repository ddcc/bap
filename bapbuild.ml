open Ocamlbuild_pack
open Ocamlbuild_plugin
open Core_kernel.Std

let syntax_packages = List.map [
    "sexplib";
    "comparelib";
    "fieldslib";
    "variantslib";
  ] ~f:(fun pkg -> pkg ^ "." ^ "syntax")

let default_pkgs = ["bap"; "bap.plugins"; "core_kernel"]

let packages = default_pkgs @ syntax_packages

let default_tags = [
  "linkall";
  "thread";
  "debug";
  "annot";
  "bin_annot";
  "short_paths"
]

let set_default_flags () : unit =
  Options.(begin
      use_ocamlfind := true;
      ocaml_syntax := Some "camlp4o";
      ocaml_pkgs := packages;
      tags := default_tags;
    end)


let extern_deps_link_flags () =
  let interns = packages |>
                List.map ~f:Findlib.query |>
                Findlib.topological_closure in
  !Options.ocaml_pkgs |>
  List.map ~f:Findlib.query |>
  List.filter ~f:(fun pkg -> not (List.mem interns pkg)) |>
  Findlib.topological_closure |>
  Findlib.link_flags_native

let symlink env =
  if Options.make_links.contents then
    Cmd (S [A"ln"; A"-sf";
            P (env (!Options.build_dir / "%.plugin"));
            A Pathname.parent_dir_name])
  else Nop

let plugin () =
  rule "bap: cmxa & a -> plugin"
    ~prods:["%.plugin"]
    ~deps:["%.cmxa"; "%" -.- !Options.ext_lib]
    (fun env _ ->
       Seq [Cmd (S [
           !Options.ocamlopt;
           A "-linkpkg";
           A "-shared";
           S [extern_deps_link_flags ()];
           P (env "%.cmxa");
           A "-o"; Px (env "%.plugin")
         ]);
          symlink env
         ])

let main () =
  set_default_flags ();
  Command.jobs := 4;
  Ocamlbuild_plugin.dispatch (function
      | Before_rules -> plugin ()
      | _ -> ());
  Ocamlbuild_unix_plugin.setup ();
  Main.main ()

let () = main ()
