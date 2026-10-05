class_name ContentLoader
extends RefCounted
## Loads every .tres/.res under a folder, recursively.

static func load_all(root: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(root)
	if dir == null:
		push_warning("ContentLoader: cannot open '%s'" % root)
		return out
	var subdirs := dir.get_directories()
	subdirs.sort()
	for sub in subdirs:
		out.append_array(load_all(root.path_join(sub)))
	var files := dir.get_files()
	files.sort()
	for file in files:
		# Exported builds list resources with a ".remap" suffix; the plain path still loads.
		var plain := file.trim_suffix(".remap")
		if plain.ends_with(".tres") or plain.ends_with(".res"):
			var res := ResourceLoader.load(root.path_join(plain))
			if res != null:
				out.append(res)
			else:
				push_warning("ContentLoader: failed to load '%s'" % root.path_join(plain))
	return out
