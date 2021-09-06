#ifndef GEEF_H
#define GEEF_H

#include <git2.h>
#include "erl_nif.h"

ERL_NIF_TERM geef_error(ErlNifEnv *env);
ERL_NIF_TERM geef_error_struct(ErlNifEnv *env, int code);
ERL_NIF_TERM geef_oom(ErlNifEnv *env);

typedef struct {
	ERL_NIF_TERM ok;
	ERL_NIF_TERM error;
	ERL_NIF_TERM nil;
	ERL_NIF_TERM true;
	ERL_NIF_TERM false;
	ERL_NIF_TERM repository;
	ERL_NIF_TERM oid;
	ERL_NIF_TERM symbolic;
	ERL_NIF_TERM commit;
	ERL_NIF_TERM tree;
	ERL_NIF_TERM blob;
	ERL_NIF_TERM tag;
	ERL_NIF_TERM format_patch;
	ERL_NIF_TERM format_patch_header;
	ERL_NIF_TERM format_raw;
	ERL_NIF_TERM format_name_only;
	ERL_NIF_TERM format_name_status;
	ERL_NIF_TERM diff_opts_pathspec;
	ERL_NIF_TERM diff_opts_context_lines;
	ERL_NIF_TERM diff_opts_interhunk_lines;
	ERL_NIF_TERM undefined;
	ERL_NIF_TERM toposort;
	ERL_NIF_TERM timesort;
	ERL_NIF_TERM reversesort;
	ERL_NIF_TERM iterover;
	ERL_NIF_TERM reflog_entry;

	ERL_NIF_TERM indexer_total_objects;
	ERL_NIF_TERM indexer_indexed_objects;
	ERL_NIF_TERM indexer_received_objects;
	ERL_NIF_TERM indexer_local_objects;
	ERL_NIF_TERM indexer_total_deltas;
	ERL_NIF_TERM indexer_indexed_deltas;
	ERL_NIF_TERM indexer_received_bytes;

	ERL_NIF_TERM zlib_need_dict;
	ERL_NIF_TERM zlib_data_error;
	ERL_NIF_TERM zlib_stream_error;
	ERL_NIF_TERM enomem;
	ERL_NIF_TERM eunknown;
	ERL_NIF_TERM estruct;
	ERL_NIF_TERM emod;
	ERL_NIF_TERM ex;
	ERL_NIF_TERM emsg;
	ERL_NIF_TERM ecode;
} geef_atoms;

extern geef_atoms atoms;

git_strarray git_strarray_from_list(ErlNifEnv *env, ERL_NIF_TERM list);

/** NUL-terminate a binary */
int geef_terminate_binary(ErlNifBinary *bin);
/** Copy a string into a binary */
int geef_string_to_bin(ErlNifBinary *bin, const char *str);

#endif
