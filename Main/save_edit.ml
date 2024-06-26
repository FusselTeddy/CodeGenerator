
let bytes_to_int_list b =
  let res = ref [] in
  b |> Bytes.iter (
    fun c -> res := (Char.code c)::(!res)
  ) ;
  List.rev (!res)

let main_box_name filename =
  let inc = open_in_gen [Open_rdonly;Open_binary] 0 filename in
  let (addr, section) = Save.read_section inc Save.box_names_section_id in
  close_in inc ;
  let current = Save.extract_box_names_from_section section in
  let len = Bytes.length current in
  Format.printf "Current data (in hexadecimal):@." ;
  current |> Bytes.iter (fun c -> Format.printf "%02X " (Char.code c)) ;
  Format.printf "@." ;
  begin try (
    let boxes = Boxes.split_raw_into_boxes (bytes_to_int_list current) in
    Boxes.pp_boxes_names Format.std_formatter boxes
  ) with _ -> () end ;
  Format.printf "@.Please enter new data (in hexadecimal):@." ;
  let line = read_line () in
  let inc_data = Scanf.Scanning.from_string line in
  let rec aux i =
    try
      let h = Scanf.bscanf inc_data " %X" (fun i -> i) in
      if i >= len then Format.printf "Warning: Data has been truncated@."
      else (
        Bytes.set current i (Char.chr h) ;
        aux (i+1)
      )
    with End_of_file -> ()
  in
  aux 0 ;
  let oc = open_out_gen [Open_wronly;Open_binary] 0 filename in
  Save.update_box_names section current ;
  Save.write_section oc addr section ;
  close_out oc ;
  Format.printf "Save has been successfully modified.@."

let main_team filename =
  let inc = open_in_gen [Open_rdonly;Open_binary] 0 filename in
  let (addr, section) = Save.read_section inc Save.team_items_section_id in
  close_in inc ;
  let team = Save.extract_team_from_section section in
  Format.printf "Which pokemon do you want to modify? (1-%i)@." (List.length team) ;
  Format.printf "(write 0 to create a new one at the end)@." ;
  let i = (read_int ()) - 1 in

  if i < 0
  then begin
    if List.length team >= 6
    then Format.printf "Full team, please remove a pokemon before.@."
    else (
      let current = Save.empty_pkmn () in
      let data = Structure.extract_data current in
      let offset =
        Structure.pkmn_from_bytes current |>
        Structure.species_offset_relative_to_data in
      Format.printf "Please enter new species (in hexadecimal):@." ;
      let line = read_line () in
      let species = Scanf.sscanf line " %X" (fun i -> i) in
      Bytes.set_uint16_le data offset species ;
      Structure.update_with_data current data ;
      let team = team@[current] in
      let oc = open_out_gen [Open_wronly;Open_binary] 0 filename in
      Save.update_team section team ;
      Save.write_section oc addr section ;
      close_out oc ;
      Format.printf "Save has been successfully modified.@."
    )
  end else begin
    let current = List.nth team i in

    let data = Structure.extract_data current in
    let offset =
      Structure.pkmn_from_bytes current |>
      Structure.species_offset_relative_to_data in
    let species = Bytes.get_uint16_le data offset in
    Format.printf "Current species (in hexadecimal): %04X@." species ;
    Format.printf "Please enter new species (in hexadecimal, blank to remove):@." ;
    let line = read_line () in
    let team =
      if String.equal (String.trim line) ""
      then
        List.filteri (fun j _ -> j <> i) team
      else
        let species = Scanf.sscanf line " %X" (fun i -> i) in
        Bytes.set_uint16_le data offset species ;
        Structure.update_with_data current data ;
        team
    in
    let oc = open_out_gen [Open_wronly;Open_binary] 0 filename in
    Save.update_team section team ;
    Save.write_section oc addr section ;
    close_out oc ;
    Format.printf "Save has been successfully modified.@."
  end

  let main_read filename =
    let inc = open_in_gen [Open_rdonly;Open_binary] 0 filename in
    let (_, section) = Save.read_section inc Save.team_items_section_id in
    close_in inc ;
    let team = Save.extract_team_from_section section in
    Format.printf "Which pokemon do you want to read? (1-%i)@." (List.length team) ;
    let i = (read_int ()) - 1 in
    let current = List.nth team i in

    Format.printf "Which substructure to read ? (GAEM)@." ;
    let s = read_line () in
    let pkmn = Structure.pkmn_from_bytes current in
    let offset = Structure.substructure_offset pkmn (s.[0]) in

    for o=0 to 3 do
      let v = Bytes.get_int32_le current (offset+o*4) in
      let v = Structure.decrypt_aligned_int32 pkmn v in
      Format.printf " %08lX" v
    done ;
    Format.printf "@."

let () =
  (*Printexc.record_backtrace true ;*)
  let filenames = Utils.enumerate_files (Sys.getcwd ()) ".sav" in
  filenames |> List.iteri (fun i str -> Format.printf "%i. %s@." i str) ;
  Format.printf "Your choice: @?" ;
  let filename = List.nth filenames (read_int ()) in
  Format.printf "1. Modify box names@." ;
  Format.printf "2. Modify team@." ;
  Format.printf "3. Read team@." ;
  Format.printf "Your choice: @?" ;
  let choice = read_int () in
  if choice = 1 then main_box_name filename
  else if choice = 2 then main_team filename
  else if choice = 3 then main_read filename
  else Format.printf "No action performed.@."
