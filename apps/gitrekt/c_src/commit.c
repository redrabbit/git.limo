#include "geef.h"
#include "repository.h"
#include "object.h"
#include "oid.h"
#include "signature.h"
#include <string.h>
#include <git2.h>
#include <git2/sys/commit.h>

ERL_NIF_TERM
geef_commit_tree_id(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	const git_oid *id;
	geef_object *obj;
	ErlNifBinary bin;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	id = git_commit_tree_id((git_commit *) obj->obj);

	if (geef_oid_bin(&bin, id) < 0)
		return geef_oom(env);

	return enif_make_binary(env, &bin);
}

ERL_NIF_TERM
geef_commit_tree(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
	geef_object *obj, *tree;
	ERL_NIF_TERM term_tree;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	tree = enif_alloc_resource(geef_object_type, sizeof(geef_object));

	if (git_commit_tree((git_tree **) &tree->obj, (git_commit *) obj->obj) < 0)
		return geef_error(env);

	term_tree = enif_make_resource(env, tree);
	enif_release_resource(tree);

	if (geef_oid_bin(&bin, git_object_id(tree->obj)) < 0)
		return geef_oom(env);

	tree->repo = obj->repo;
	enif_keep_resource(tree->repo);

	return enif_make_tuple3(env, atoms.ok, enif_make_binary(env, &bin), term_tree);
}

ERL_NIF_TERM
geef_commit_create(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	ErlNifBinary bin;
	char *ref = NULL, *encoding = NULL, *message = NULL;
	git_signature *author = NULL, *committer = NULL;
	ERL_NIF_TERM err, head, tail;
	unsigned int parents_len, i;
	git_oid tree, *parents_ids, commit_id;
	const git_oid **parents_ids_ptrs;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (enif_compare(argv[1], atoms.undefined)) {
		if (!enif_inspect_iolist_as_binary(env, argv[1], &bin))
		     return enif_make_badarg(env);
		ref = strndup((char *)bin.data, bin.size);
		if (ref == NULL)
			return geef_oom(env);
	}

	if (geef_signature_from_erl(&author, env, &err, argv[2]) < 0)
		return err;

	if (geef_signature_from_erl(&committer, env, &err, argv[3]) < 0) {
		git_signature_free(author);
		return err;
	}

	if (enif_compare(argv[4], atoms.undefined)) {
		if (!enif_inspect_iolist_as_binary(env, argv[4], &bin))
		     return enif_make_badarg(env);
		encoding = strndup((char *)bin.data, bin.size);
		if (encoding == NULL)
			return geef_oom(env);
	}

	if (!enif_inspect_iolist_as_binary(env, argv[5], &bin))
		return enif_make_badarg(env);

	message = strndup((char *)bin.data, bin.size);
	if (message == NULL)
		return geef_oom(env);

	if (!enif_inspect_binary(env, argv[6], &bin))
		return enif_make_badarg(env);
	if (bin.size != GIT_OID_RAWSZ)
		return enif_make_badarg(env);

	git_oid_fromraw(&tree, bin.data);

	if (!enif_get_list_length(env, argv[7], &parents_len))
		return enif_make_badarg(env);

	parents_ids = calloc(parents_len, sizeof(git_oid));
	if (parents_ids == NULL)
		return geef_oom(env);

	parents_ids_ptrs = calloc(parents_len, sizeof(git_oid *));
	if (parents_ids_ptrs == NULL)
		return geef_oom(env);

	i = 0;
	tail = argv[7];
	while (enif_get_list_cell(env, tail, &head, &tail)) {
		if (!enif_inspect_binary(env, head, &bin))
			return enif_make_badarg(env);
		if (bin.size != GIT_OID_RAWSZ)
			return enif_make_badarg(env);

		git_oid_fromraw(&parents_ids[i], bin.data);
		parents_ids_ptrs[i] = &parents_ids[i];
		i++;
	}

	if (git_commit_create_from_ids(&commit_id, repo->repo, ref, author, committer, encoding, message,
			      &tree, parents_len, parents_ids_ptrs) < 0)
		return geef_error(env);

	if (!enif_realloc_binary(&bin, GIT_OID_RAWSZ))
		return geef_oom(env);

	memcpy(bin.data, &commit_id, GIT_OID_RAWSZ);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &bin));
}

ERL_NIF_TERM
geef_commit_message(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
	geef_object *obj;
	const char *msg;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	msg = git_commit_message((git_commit *) obj->obj);
	if (geef_string_to_bin(&bin, msg) < 0)
		return geef_error(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &bin));
}
