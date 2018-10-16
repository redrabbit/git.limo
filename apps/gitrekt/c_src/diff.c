#include <string.h>
#include <git2.h>

#include "geef.h"
#include "object.h"
#include "oid.h"
#include "diff.h"

static git_diff_format_t diff_format_atom2type(ERL_NIF_TERM term)
{
	if (!enif_compare(term, atoms.format_patch))
		return GIT_DIFF_FORMAT_PATCH;
	else if (!enif_compare(term, atoms.format_patch_header))
		return GIT_DIFF_FORMAT_PATCH_HEADER;
	else if (!enif_compare(term, atoms.format_raw))
		return GIT_DIFF_FORMAT_RAW;
	else if (!enif_compare(term, atoms.format_name_only))
		return GIT_DIFF_FORMAT_NAME_ONLY;
	else if (!enif_compare(term, atoms.format_name_status))
		return GIT_DIFF_FORMAT_NAME_STATUS;

	return GIT_DIFF_FORMAT_RAW;
}

void geef_diff_free(ErlNifEnv *env, void *cd)
{
	geef_diff *diff = (geef_diff *) cd;
	enif_release_resource(diff->repo);
	git_diff_free(diff->diff);
}

ERL_NIF_TERM
geef_diff_tree(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	geef_object *old_tree;
	geef_object *new_tree;
	geef_diff *diff;
	ERL_NIF_TERM diff_term;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_get_resource(env, argv[1], geef_object_type, (void **) &old_tree))
		return enif_make_badarg(env);

	if (!enif_get_resource(env, argv[2], geef_object_type, (void **) &new_tree))
		return enif_make_badarg(env);

	diff = enif_alloc_resource(geef_diff_type, sizeof(geef_diff));
	if (!diff)
		return geef_oom(env);

	if (git_diff_tree_to_tree(&diff->diff, repo->repo, (git_tree *)old_tree->obj, (git_tree *)new_tree->obj, NULL) < 0) {
		enif_release_resource(diff);
		return geef_error(env);
	}

	diff_term = enif_make_resource(env, diff);
	enif_release_resource(diff);
	diff->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple2(env, atoms.ok, diff_term);
}

ERL_NIF_TERM
geef_diff_format(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_diff *diff;
	git_diff_format_t format;
	git_buf buf = { NULL };
	ErlNifBinary data;

	if (!enif_get_resource(env, argv[0], geef_diff_type, (void **) &diff))
		return enif_make_badarg(env);

	if (git_diff_to_buf(&buf, diff->diff, diff_format_atom2type(argv[1])) < 0) {
		return geef_error(env);
	}

	if (!enif_alloc_binary(buf.size, &data)) {
		git_buf_free(&buf);
		return geef_oom(env);
	}

	memcpy(data.data, buf.ptr, data.size);
	git_buf_free(&buf);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &data));
}
