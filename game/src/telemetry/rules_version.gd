class_name RulesVersion
extends RefCounted
## Identifies the game rules a run used: a hash of the simulation code and the
## game data files (ADR-0003). It changes whenever any of them change, so it
## cannot be forgotten.

## The loader is included because it shapes what the simulation is given.
const RULE_FOLDERS: PackedStringArray = ["res://src/sim", "res://src/loading", "res://data"]
## Engine metadata and docs, which say nothing about the rules.
const IGNORED_SUFFIXES: PackedStringArray = [".uid", ".import", ".md"]


## First 16 hex characters of SHA-256 over every file's full path and
## contents, folders in the order given and files in sorted order, with line
## endings normalised to LF so Windows and Linux agree. Returns an empty
## string, and reports an error, if a folder cannot be opened: a rules version
## that silently skipped a folder would hide a change to the rules.
static func compute(folders: PackedStringArray = RULE_FOLDERS) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for folder: String in folders:
		if not DirAccess.dir_exists_absolute(folder):
			push_error("RulesVersion: cannot open %s" % folder)
			return ""
		for relative: String in _files(folder, ""):
			var path := folder.path_join(relative)
			var text := FileAccess.get_file_as_string(path)
			hashing.update(("%s\n" % path).to_utf8_buffer())
			hashing.update(text.replace("\r\n", "\n").to_utf8_buffer())
	return hashing.finish().hex_encode().substr(0, 16)


static func _files(folder: String, prefix: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var directory := DirAccess.open(folder.path_join(prefix))
	if directory == null:
		return found
	for name: String in directory.get_files():
		if not IGNORED_SUFFIXES.has("." + name.get_extension()):
			found.append(prefix.path_join(name))
	for name: String in directory.get_directories():
		found.append_array(_files(folder, prefix.path_join(name)))
	found.sort()
	return found
