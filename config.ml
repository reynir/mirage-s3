open Mirage

let stack = generic_stackv4v6 default_network
let he = generic_happy_eyeballs stack
let dns = generic_dns_client stack he

let mirage_s3 =
  let packages = [
    package "aws-s3-mirage"
      ~pin:"git+https://github.com/reynir/aws-s3.git#mirage";
    package "aws-s3"
      ~pin:"git+https://github.com/reynir/aws-s3.git#mirage";
  ] in
  main ~packages ~deps:[ dep dns ] ~pos:__POS__ "Unikernel.Make" (stackv4v6 @-> happy_eyeballs @-> job)

let () =
  register "mirage-s3"
    [ mirage_s3 $ stack $ he ]
