#include "geef.h"
#include "oid.h"
#include "index.h"
#include "object.h"
#include <string.h>
#include <git2.h>

void geef_index_free(ErlNifEnv *env, void *cd)
{
	geef_index *index = (geef_index *) cd;
	git_index_free(index->index);
}

ERL_NIF_TERM entry_to_term(ErlNifEnv *env, const git_index_entry *entry)
{
	ErlNifBinary id, path;
	size_t len;

	if (geef_oid_bin(&id, &entry->id) < 0)
		return geef_oom(env);

	len = strlen(entry->path);
	if (!enif_alloc_binary(len, &path)) {
		enif_release_binary(&id);
		return geef_oom(env);
	}
	memcpy(path.data, entry->path, len);

	return enif_make_tuple(env, 13, atoms.ok,
			       enif_make_int64(env, entry->ctime.seconds),
			       enif_make_int64(env, entry->mtime.seconds),
			       enif_make_uint(env, entry->dev),
			       enif_make_uint(env, entry->ino),
			       enif_make_uint(env, entry->mode),
			       enif_make_uint(env, entry->uid),
			       enif_make_uint(env, entry->gid),
			       enif_make_int64(env, entry->file_size),
			       enif_make_binary(env, &id),
			       enif_make_uint(env, entry->flags),
			       enif_make_uint(env, entry->flags_extended),
			       enif_make_binary(env, &path));
}

ERL_NIF_TERM
geef_index_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_index *index;
	ERL_NIF_TERM term;

	index = enif_alloc_resource(geef_index_type, sizeof(geef_index));
	if (!index)
		return geef_oom(env);

	error = git_index_new(&index->index);
	if (error < 0)
		return geef_error_struct(env, error);

	term = enif_make_resource(env, index);
	enif_release_resource(index);

	return enif_make_tuple2(env, atoms.ok, term);
}

ERL_NIF_TERM
geef_index_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_index *index;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	error = git_index_write(index->index);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_index_write_tree(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_index *index;
	geef_repository *repo;
	ErlNifBinary bin;
	git_oid id;
	int error;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	if (argc == 2) {
		if (!enif_get_resource(env, argv[1], geef_repository_type, (void **) &repo))
			return enif_make_badarg(env);

		error = git_index_write_tree_to(&id, index->index, repo->repo);
	} else {
		error = git_index_write_tree(&id, index->index);
	}

	if (error < 0)
		return geef_error_struct(env, error);

	if (geef_oid_bin(&bin, &id) < 0)
		return geef_oom(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &bin));
}

ERL_NIF_TERM
geef_index_read_tree(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_index *index;
	geef_object *tree;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	if (!enif_get_resource(env, argv[1], geef_object_type, (void **) &tree))
		return enif_make_badarg(env);

	error = git_index_read_tree(index->index, (git_tree *)tree->obj);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_index_add(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_index *index;
	const ERL_NIF_TERM *eentry;
	int arity, error;
	unsigned int tmp;
	ErlNifBinary path, id;
	git_index_entry entry;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	if (!enif_get_tuple(env, argv[1], &arity, &eentry))
		return enif_make_badarg(env);

	memset(&entry, 0, sizeof(entry));

	if (enif_compare(eentry[0], atoms.undefined) &&
	    !enif_get_int(env, eentry[0], &entry.ctime.seconds))
		return enif_make_badarg(env);

	if (enif_compare(eentry[1], atoms.undefined) &&
	    !enif_get_int(env, eentry[1], &entry.mtime.seconds))
		return enif_make_badarg(env);

	if (enif_compare(eentry[2], atoms.undefined) &&
	    !enif_get_uint(env, eentry[2], &entry.dev))
		return enif_make_badarg(env);

	if (enif_compare(eentry[3], atoms.undefined) &&
	    !enif_get_uint(env, eentry[3], &entry.ino))
		return enif_make_badarg(env);

	if (!enif_get_uint(env, eentry[4], &entry.mode))
		return enif_make_badarg(env);

	if (enif_compare(eentry[5], atoms.undefined) &&
	    !enif_get_uint(env, eentry[5], &entry.uid))
		return enif_make_badarg(env);

	if (enif_compare(eentry[6], atoms.undefined) &&
	    !enif_get_uint(env, eentry[6], &entry.gid))
		return enif_make_badarg(env);

	if (!enif_get_uint(env, eentry[7], &entry.file_size))
		return enif_make_badarg(env);

	/* [8] comes later */

	tmp = 0;
	if (enif_compare(eentry[9], atoms.undefined) &&
	    !enif_get_uint(env, eentry[9], &tmp))
		return enif_make_badarg(env);
	entry.flags = tmp;

	tmp = 0;
	if (enif_compare(eentry[10], atoms.undefined) &&
	    !enif_get_uint(env, eentry[10], &tmp))
		return enif_make_badarg(env);
	entry.flags_extended = tmp;

	if (!enif_inspect_binary(env, eentry[11], &path))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&path))
		return geef_oom(env);

	entry.path = (char *) path.data;

	if (!enif_inspect_binary(env, eentry[8], &id))
		return enif_make_badarg(env);

	git_oid_fromraw(&entry.id, id.data);

	error = git_index_add(index->index, &entry);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_index_remove(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_index *index;
	ErlNifBinary path;
	unsigned int stage;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	if (!enif_get_uint(env, argv[2], &stage))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &path))
		return enif_make_badarg(env);

	if (geef_terminate_binary(&path) < 0) {
		enif_release_binary(&path);
		return geef_oom(env);
	}

	error = git_index_remove(index->index, (char *) path.data, stage);
	enif_release_binary(&path);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_index_remove_dir(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_index *index;
	ErlNifBinary path;
	unsigned int stage;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	if (!enif_get_uint(env, argv[2], &stage))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &path))
		return enif_make_badarg(env);

	if (geef_terminate_binary(&path) < 0) {
		enif_release_binary(&path);
		return geef_oom(env);
	}

	error = git_index_remove_directory(index->index, (char *) path.data, stage);
	enif_release_binary(&path);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_index_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_index *index;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	return enif_make_uint(env, git_index_entrycount(index->index));
}

ERL_NIF_TERM
geef_index_nth(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	size_t nth;
	geef_index *index;
	const git_index_entry *entry;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	if (!enif_get_ulong(env, argv[1], &nth))
		return enif_make_badarg(env);

	entry = git_index_get_byindex(index->index, nth);
	if (entry == NULL)
		return geef_error(env);

	return entry_to_term(env, entry);
}

ERL_NIF_TERM
geef_index_get(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	unsigned int stage;
	ErlNifBinary path;
	geef_index *index;
	const git_index_entry *entry;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	if (!enif_get_uint(env, argv[2], &stage))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &path))
		return enif_make_badarg(env);

	if (geef_terminate_binary(&path) < 0) {
		enif_release_binary(&path);
		return geef_oom(env);
	}

	entry = git_index_get_bypath(index->index, (char *) path.data, stage);
	enif_release_binary(&path);
	if (entry == NULL)
		return geef_error(env);

	return entry_to_term(env, entry);
}

ERL_NIF_TERM
geef_index_clear(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_index *index;

	if (!enif_get_resource(env, argv[0], geef_index_type, (void **) &index))
		return enif_make_badarg(env);

	git_index_clear(index->index);

	return atoms.ok;
}
