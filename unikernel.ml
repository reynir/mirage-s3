module K = struct
  open Cmdliner
  open Term.Syntax

  let endpoint =
    Mirage_runtime.register_arg @@
    let host =
      let doc = Arg.info ~doc:"Garage host" [ "host" ] in
      Arg.(required & opt (some string) None doc)
    in
    let+ host = host in
    let region = Aws_s3.Region.garage ~port:3900 ~host () in
    Aws_s3.Region.endpoint ~inet:`V4 ~scheme:`Http region

  let bucket =
    Mirage_runtime.register_arg @@
    let doc = Arg.info ~doc:"S3 bucket name" [ "bucket" ] in
    Arg.(required & opt (some string) None doc)

  let credentials =
    let access_key =
      let doc = Arg.info ~doc:"S3 access key" [ "access-key" ] in
      Arg.(required & opt (some string) None doc)
    and secret_key =
      let doc = Arg.info ~doc:"S3 secret key" [ "secret-key" ] in
      Arg.(required & opt (some string) None doc)
    in
    Mirage_runtime.register_arg @@
    let open Term.Syntax in
    let+ access_key = access_key
    and+ secret_key = secret_key in
    Aws_s3.Credentials.make ~access_key ~secret_key ()
end

module Make(Stack : Tcpip.Stack.V4V6)(He : Happy_eyeballs_mirage.S with type flow = Stack.TCP.flow) = struct

  open Lwt.Syntax

  let start stack he _ =
    let module Aws_io = struct
      include Aws_s3_mirage.Io.Make(Stack.TCP)(He)
      module Net = struct
        let connect ?connect_timeout_ms ~inet ~host ~port ~scheme () =
          Net.connect he ?connect_timeout_ms ~inet ~host ~port ~scheme ()
      end
    end
    in

    let module S3 = Aws_s3.S3.Make(Aws_io) in

    let endpoint = K.endpoint () and bucket = K.bucket () and credentials = K.credentials () in
    let* r = S3.ls ~credentials ~endpoint ~bucket () in
    match r with
    | Error _ ->
      print_endline "Some error occurred.";
      exit 42
    | Ok (content_list, cont) ->
      Fmt.pr "Found %u items:\n" (List.length content_list);
      List.iter (fun { S3.key; etag; size; last_modified; _ } ->
          let last_modified = Ptime.of_float_s last_modified |> Option.get in
          Fmt.pr "%S\t%u B\t%s\t%a\n" key size etag (Ptime.pp_human ()) last_modified)
        content_list;
      match cont with
      | Done -> Lwt.return_unit
      | More _ ->
        Fmt.pr "And many more items!\n";
        Lwt.return_unit
end
