#include <git2.h>
#include <string.h>
#include <stdio.h>

#include "oid.h"
#include "geef.h"
#include "tree.h"

static int geef_string_bin(ErlNifBinary *bin, const char *str)
{
	size_t len;

	len = strlen(str);
	if (!enif_alloc_binary(len, bin))
		return -1;

	memcpy(bin->data, str, len);

	return 0;
}

static ERL_NIF_TERM tree_entry_to_term(ErlNifEnv *env, const git_tree_entry *entry)
{
	ErlNifBinary name, oid;

	if (geef_oid_bin(&oid, git_tree_entry_id(entry)) < 0)
		return geef_oom(env);

	if (geef_string_bin(&name, git_tree_entry_name(entry)) < 0) {
		enif_release_binary(&name);
		return geef_oom(env);
	}

	return enif_make_tuple5(env, atoms.ok, enif_make_int(env, git_tree_entry_filemode(entry)),
				 geef_object_type2atom(git_tree_entry_type(entry)),
				 enif_make_binary(env, &oid), enif_make_binary(env, &name));
}

ERL_NIF_TERM
geef_tree_byid(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
	geef_object *obj;
    git_oid id;
	const git_tree_entry *entry;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);


	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (bin.size != GIT_OID_RAWSZ)
		return enif_make_badarg(env);

	git_oid_fromraw(&id, bin.data);

	entry = git_tree_entry_byid((git_tree *)obj->obj, &id);
    if (entry == NULL)
        return geef_oom(env);

	return tree_entry_to_term(env, entry);
}

ERL_NIF_TERM
geef_tree_bypath(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_object *obj;
	ErlNifBinary bin;
	git_tree_entry *entry;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	error = git_tree_entry_bypath(&entry, (git_tree *)obj->obj, (char *) bin.data);
	if (error < 0)
		return geef_error_struct(env, error);

	enif_release_binary(&bin);
	return tree_entry_to_term(env, entry);
}

ERL_NIF_TERM
geef_tree_nth(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_object *obj;
	const git_tree_entry *entry;
	unsigned int nth;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	if (!enif_get_uint(env, argv[1], &nth))
		return enif_make_badarg(env);

	entry = git_tree_entry_byindex((git_tree *)obj->obj, nth);

	if (!entry)
		return geef_oom(env);

	return tree_entry_to_term(env, entry);
}

ERL_NIF_TERM
geef_tree_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_object *obj;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_uint64(env, git_tree_entrycount((git_tree *) obj->obj)));
}
