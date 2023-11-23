#include <string.h>
#include <git2.h>

#include "geef.h"
#include "object.h"
#include "oid.h"
#include "diff.h"

typedef struct {
	ERL_NIF_TERM hunk;
	ERL_NIF_TERM lines;
} diff_hunk;

typedef struct {
	ERL_NIF_TERM delta;
	diff_hunk **hunks;
	size_t size;
} diff_delta;

typedef struct {
	ErlNifEnv *env;
	diff_delta **deltas;
	size_t size;
} diff_pack;

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

	return GIT_DIFF_FORMAT_PATCH;
}

static git_diff_options diff_opts_atom2type(ErlNifEnv *env, ERL_NIF_TERM keyword)
{
	ERL_NIF_TERM head, tail, key, val;
	unsigned int size;
    int arity;
	size_t i;
	const ERL_NIF_TERM *array;
	git_diff_options opts;

	git_diff_init_options(&opts, GIT_DIFF_OPTIONS_VERSION);

	if (!enif_get_list_length(env, keyword, &size))
		return opts;

	tail = keyword;
	for(i = 0; i < size; i++) {
		if (!enif_get_list_cell(env, tail, &head, &tail))
			return opts;

		if (!enif_get_tuple(env, head, &arity, &array))
			return opts;

		if (arity != 2 ) {
			return opts;
		}

		key = array[0];
		val = array[1];

		if (!enif_compare(key, atoms.diff_opts_context_lines))
			opts.context_lines = val;
		else if (!enif_compare(key, atoms.diff_opts_interhunk_lines))
			opts.interhunk_lines = val;
		else if (!enif_compare(key, atoms.diff_opts_pathspec)) {
			opts.pathspec = git_strarray_from_list(env, val);
		}
	}

	return opts;
}

static ERL_NIF_TERM diff_file_to_term(ErlNifEnv *env, const git_diff_file *file)
{
	ErlNifBinary path, oid;

	if (geef_oid_bin(&oid, &file->id) < 0)
		return geef_oom(env);

	if (geef_string_to_bin(&path, file->path) < 0) {
		enif_release_binary(&path);
		return geef_oom(env);
	}

	return enif_make_tuple4(env,
		enif_make_binary(env, &oid),
		enif_make_binary(env, &path),
		enif_make_int64(env, file->size),
		enif_make_uint(env, file->mode)
	);
}

static ERL_NIF_TERM diff_line_to_term(ErlNifEnv *env, const git_diff_line *line)
{
	ErlNifBinary bin;

	if (enif_alloc_binary(line->content_len, &bin) < 0)
		return geef_oom(env);

	memcpy(bin.data, line->content, line->content_len);

	return enif_make_tuple6(env,
		enif_make_uint(env, line->origin),
		enif_make_int(env, line->old_lineno),
		enif_make_int(env, line->new_lineno),
		enif_make_int(env, line->num_lines),
		enif_make_int64(env, line->content_offset),
		enif_make_binary(env, &bin)
	);
}


static ERL_NIF_TERM diff_hunk_to_term(ErlNifEnv *env, const git_diff_hunk *hunk)
{
	ErlNifBinary header;

	if (geef_string_to_bin(&header, hunk->header) < 0) {
		enif_release_binary(&header);
		return geef_oom(env);
	}

	return enif_make_tuple5(env,
		enif_make_binary(env, &header),
		enif_make_int(env, hunk->old_start),
		enif_make_int(env, hunk->old_lines),
		enif_make_int(env, hunk->new_start),
		enif_make_int(env, hunk->new_lines)
	);
}

static ERL_NIF_TERM diff_delta_to_term(ErlNifEnv *env, const git_diff_delta *delta)
{
	return enif_make_tuple4(env,
		diff_file_to_term(env, &delta->old_file),
		diff_file_to_term(env, &delta->new_file),
		enif_make_uint(env, delta->nfiles),
		enif_make_uint(env, delta->similarity)
	);
}

static int diff_delta_file_cb(const git_diff_delta *delta, float progress, void *payload)
{
	diff_pack* pack = payload;
	diff_delta *delta_pack = malloc(sizeof(diff_delta));

	*delta_pack = (diff_delta){ diff_delta_to_term(pack->env, delta), NULL, 0 };
	pack->deltas[pack->size++] = delta_pack;
	return 0;
}

static int diff_delta_bin_cb(const git_diff_delta *delta, const git_diff_binary *binary, void *payload)
{
	return 0;
}

static int diff_delta_hunk_cb(const git_diff_delta *delta, const git_diff_hunk *hunk, void *payload)
{
	diff_pack* pack = payload;
	diff_delta *last_delta = pack->deltas[pack->size-1];
	if(last_delta->hunks == NULL) {
		last_delta->hunks = (diff_hunk **)malloc(sizeof(diff_hunk *));
		last_delta->size = 1;
	} else {
		last_delta->hunks = realloc(last_delta->hunks, sizeof(diff_hunk *) * ++last_delta->size);
	}

	diff_hunk *delta_hunk = malloc(sizeof(diff_hunk));

	*delta_hunk = (diff_hunk){ diff_hunk_to_term(pack->env, hunk), delta_hunk->lines = enif_make_list(pack->env, 0) };
	last_delta->hunks[last_delta->size-1] = delta_hunk;

	return 0;
}

static int diff_delta_line_cb(const git_diff_delta *delta, const git_diff_hunk *hunk, const git_diff_line *line, void *payload)
{
	diff_pack *pack = payload;
	diff_delta *last_delta = pack->deltas[pack->size-1];
	diff_hunk *last_hunk = last_delta->hunks[last_delta->size-1];
	last_hunk->lines = enif_make_list_cell(pack->env, diff_line_to_term(pack->env, line), last_hunk->lines);

	return 0;
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
	int error;
        int nums_of_null_tree = 0;
	geef_repository *repo;
        geef_object *old_tree = NULL;
        geef_object *new_tree = NULL;
	geef_diff *diff;
	git_diff_options diff_opts;
	ERL_NIF_TERM diff_term;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_get_resource(env, argv[1], geef_object_type, (void **) &old_tree))
                nums_of_null_tree += 1;

	if (!enif_get_resource(env, argv[2], geef_object_type, (void **) &new_tree))
                nums_of_null_tree += 1;

        if (nums_of_null_tree > 1) {
                return enif_make_badarg(env);
        }

	diff = enif_alloc_resource(geef_diff_type, sizeof(geef_diff));
	if (!diff)
		return geef_oom(env);

	diff_opts = diff_opts_atom2type(env, argv[3]);

        if (old_tree == NULL || new_tree == NULL) {
          error = git_diff_tree_to_tree(&diff->diff, repo->repo, old_tree ? (git_tree *)old_tree->obj : NULL, new_tree ? (git_tree *)new_tree->obj : NULL, &diff_opts);
        } else {
          error = git_diff_tree_to_tree(&diff->diff, repo->repo, (git_tree *)old_tree->obj, (git_tree *)new_tree->obj, &diff_opts);
        }

	if (error < 0) {
		enif_release_resource(diff);
		return geef_error_struct(env, error);
	}

	diff_term = enif_make_resource(env, diff);
	enif_release_resource(diff);
	diff->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple2(env, atoms.ok, diff_term);
}

ERL_NIF_TERM
geef_diff_stats(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_diff *diff;
	git_diff_stats *stats;
	int insertions, deletions, files_changed;

	if (!enif_get_resource(env, argv[0], geef_diff_type, (void **) &diff))
		return enif_make_badarg(env);

	error = git_diff_get_stats(&stats, diff->diff);
	if (error < 0)
		return geef_error_struct(env, error);

	insertions = git_diff_stats_insertions(stats);
	deletions = git_diff_stats_deletions(stats);
	files_changed = git_diff_stats_files_changed(stats);

	git_diff_stats_free(stats);

	return enif_make_tuple4(env, atoms.ok, enif_make_uint(env, files_changed), enif_make_uint(env, insertions), enif_make_uint(env, deletions));
}

ERL_NIF_TERM
geef_diff_delta_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_diff *diff;

	if (!enif_get_resource(env, argv[0], geef_diff_type, (void **) &diff))
		return enif_make_badarg(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_uint64(env, git_diff_num_deltas(diff->diff)));
}

ERL_NIF_TERM
geef_diff_deltas(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	diff_pack pack;
	geef_diff *diff;
	size_t i, j;

	if (!enif_get_resource(env, argv[0], geef_diff_type, (void **) &diff))
		return enif_make_badarg(env);

	pack = (diff_pack){ env, (diff_delta **)malloc(sizeof(git_diff_delta *) * git_diff_num_deltas(diff->diff)), 0};
	error = git_diff_foreach(diff->diff, diff_delta_file_cb, diff_delta_bin_cb, diff_delta_hunk_cb, diff_delta_line_cb, &pack);
	if (error < 0)
		return geef_error_struct(env, error);

	ERL_NIF_TERM deltas = enif_make_list(env, 0);
	for (i = 0; i < pack.size; i++) {
		diff_delta *delta = pack.deltas[i];
		ERL_NIF_TERM hunks = enif_make_list(env, 0);
		for (j = 0; j < delta->size; j++) {
			diff_hunk *hunk = delta->hunks[j];
			enif_make_reverse_list(env, hunk->lines, &hunk->lines);
			hunks = enif_make_list_cell(env, enif_make_tuple2(env, hunk->hunk, hunk->lines), hunks);
			free(hunk);
		}
		enif_make_reverse_list(env, hunks, &hunks);
		deltas = enif_make_list_cell(env, enif_make_tuple2(env, delta->delta, hunks), deltas);
		free(delta->hunks);
		free(delta);
	}

	enif_make_reverse_list(env, deltas, &deltas);
	free(pack.deltas);

	return enif_make_tuple2(env, atoms.ok, deltas);
}

ERL_NIF_TERM
geef_diff_format(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_diff *diff;
	git_buf buf = { NULL, 0, 0 };
	ErlNifBinary data;

	if (!enif_get_resource(env, argv[0], geef_diff_type, (void **) &diff))
		return enif_make_badarg(env);

	error = git_diff_to_buf(&buf, diff->diff, diff_format_atom2type(argv[1]));
	if (error < 0) {
		return geef_error_struct(env, error);
	}

	if (!enif_alloc_binary(buf.size, &data)) {
		git_buf_free(&buf);
		return geef_oom(env);
	}

	memcpy(data.data, buf.ptr, data.size);
	git_buf_free(&buf);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &data));
}
