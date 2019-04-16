#include <assert.h>
#include <string.h>

#include <libpq-fe.h>

#include <git2.h>
#include <git2/sys/odb_backend.h>
#include <git2/sys/refdb_backend.h>
#include <git2/sys/refs.h>

#include "postgres_backend.h"

#define GIT_ODB_TABLE_NAME "git_objects"
#define GIT_REFDB_TABLE_NAME "git_references"

typedef struct {
	git_odb_backend parent;
	PGconn *conn;
	int64_t repo_id;
} postgres_odb_backend;

typedef struct {
	git_refdb_backend parent;
	PGconn *conn;
	int64_t repo_id;
} postgres_refdb_backend;

typedef struct {
	git_reference_iterator parent;
	size_t current;
	PGresult *result;
	postgres_refdb_backend *backend;
} postgres_refdb_iterator;

int postgres_odb_backend__read(void **data_p, size_t *len_p, git_otype *type_p, git_odb_backend *_backend, const git_oid *oid)
{
	PGresult *result;
	postgres_odb_backend *backend;

	assert(data_p && len_p && type_p && _backend && oid);
	backend = (postgres_odb_backend *)_backend;

	const int64_t repo_id = htonll(backend->repo_id);
	const char *paramValues[2] = {(char *)&repo_id, oid->id};
	int paramLengths[2] = {sizeof(repo_id), 20};
	int paramFormats[2] = {1, 1};

	result = PQexecParams(backend->conn, "SELECT type, size, data FROM " GIT_ODB_TABLE_NAME " WHERE repo_id = $1 AND oid = $2", 2, NULL, paramValues, paramLengths, paramFormats, 1);
	if(PQresultStatus(result) != PGRES_TUPLES_OK) {
		giterr_set_str(GITERR_ODB, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	if(PQntuples(result) < 1) {
		return GIT_ENOTFOUND;
	}


	*type_p = (git_otype)ntohl(*((int *)PQgetvalue(result, 0, 0)));
	*len_p = ntohl(*((size_t *)PQgetvalue(result, 0, 1)));

	*data_p = malloc(*len_p);
	if(*data_p == NULL) {
		return GITERR_NOMEMORY;
	}

	memcpy(*data_p, PQgetvalue(result, 0, 2), *len_p);

	PQclear(result);
	return GIT_OK;
}

int postgres_odb_backend__read_prefix(git_oid *out_oid, void **data_p, size_t *len_p, git_otype *type_p, git_odb_backend *_backend, const git_oid *short_oid, unsigned int len)
{
	if (len >= GIT_OID_HEXSZ) {
		/* Just match the full identifier */
		int error = postgres_odb_backend__read(data_p, len_p, type_p, _backend, short_oid);
		if (error == 0)
			git_oid_cpy(out_oid, short_oid);

		return error;
	} else if (len < GIT_OID_HEXSZ) {
		return GIT_ERROR;
	}
}

int postgres_odb_backend__read_header(size_t *len_p, git_otype *type_p, git_odb_backend *_backend, const git_oid *oid)
{
	PGresult *result;
	postgres_odb_backend *backend;

	assert(len_p && type_p && _backend && oid);

	backend = (postgres_odb_backend *)_backend;

	const int64_t repo_id = htonll(backend->repo_id);
	const char *paramValues[2] = {(char *)&repo_id, oid->id};
	int paramLengths[2] = {sizeof(repo_id), 20};
	int paramFormats[2] = {1, 1};

	result = PQexecParams(backend->conn, "SELECT type, size FROM " GIT_ODB_TABLE_NAME " WHERE repo_id = $1 AND oid = $2", 2, NULL, paramValues, paramLengths, paramFormats, 1);
	if(PQresultStatus(result) != PGRES_TUPLES_OK) {
		giterr_set_str(GITERR_ODB, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	if(PQntuples(result) < 1) {
		return GIT_ENOTFOUND;
	}

	*type_p = (git_otype)ntohl(*((int *)PQgetvalue(result, 0, 0)));
	*len_p = ntohl(*((size_t *)PQgetvalue(result, 0, 1)));

	PQclear(result);
	return GIT_OK;
}

int postgres_odb_backend__exists(git_odb_backend *_backend, const git_oid *oid)
{
	postgres_odb_backend *backend;
	int found;
	PGresult *result;

	assert(_backend && oid);

	backend = (postgres_odb_backend *)_backend;
	found = 0;

	const int64_t repo_id = htonll(backend->repo_id);
	const char *paramValues[2] = {(char *)&repo_id, oid->id};
	int paramLengths[2] = {sizeof(repo_id), 20};
	int paramFormats[2] = {1, 1};

	result = PQexecParams(backend->conn, "SELECT type FROM " GIT_ODB_TABLE_NAME " WHERE repo_id = $1 AND oid = $2", 2, NULL, paramValues, paramLengths, paramFormats, 0);
	if(PQresultStatus(result) != PGRES_TUPLES_OK) {
		giterr_set_str(GITERR_ODB, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	if(PQntuples(result) > 0) {
		found = 1;
	}

	PQclear(result);
	return found;
}

int postgres_odb_backend__write(git_odb_backend *_backend, const git_oid *oid, const void *data, size_t len, git_otype type)
{
	PGresult *result;
	postgres_odb_backend *backend;

	assert(oid && _backend && data);

	backend = (postgres_odb_backend *)_backend;

	if (git_odb_hash(oid, data, len, type) < 0)
		return GIT_ERROR;

	const int64_t repo_id = htonll(backend->repo_id);
	const int type_n = htonl(type);
	const int size_n = htonl(len);
	const char *paramValues[5] = {(char *)&repo_id, oid->id, (char *)&type_n, (char *)&size_n, (char*)data};
	const int paramLengths[5] = {sizeof(repo_id), 20, sizeof(type_n), sizeof(size_n), len};
	const int paramFormats[5] = {1, 1, 1, 1, 1};

	result = PQexecParams(backend->conn, "INSERT INTO " GIT_ODB_TABLE_NAME " VALUES ($1, $2, $3, $4, $5)", 5, NULL, paramValues, paramLengths, paramFormats, 0);
	if(PQresultStatus(result) != PGRES_COMMAND_OK) {
		giterr_set_str(GITERR_ODB, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	PQclear(result);
	return GIT_OK;
}

void postgres_odb_backend__free(git_odb_backend *_backend)
{
	postgres_odb_backend *backend;

	assert(_backend);
	backend = (postgres_odb_backend *)_backend;

	PQfinish(backend->conn);

	free(backend);
}

int postgres_refdb_backend__exists(int *exists, git_refdb_backend *_backend, const char *ref_name)
{
	PGresult *result;
	int found = 0;
	postgres_refdb_backend *backend;

	assert(ref_name && _backend);
	backend = (postgres_refdb_backend *) _backend;

	const int64_t repo_id = htonll(backend->repo_id);
	const char *paramValues[2] = {(char *)&repo_id, ref_name};
	int paramLengths[2] = {sizeof(repo_id), strlen(ref_name)};
	int paramFormats[2] = {1, 0};

	result = PQexecParams(backend->conn, "SELECT oid FROM " GIT_REFDB_TABLE_NAME " WHERE repo_id = $1 AND name = $2", 2, NULL, paramValues, paramLengths, paramFormats, 1);
	if(PQresultStatus(result) != PGRES_TUPLES_OK)
		giterr_set_str(GITERR_REFERENCE, PQerrorMessage(backend->conn));
		return GIT_ERROR;

	if(PQntuples(result) > 0) {
		found = 1;
	}

	PQclear(result);
	return found;
}

int postgres_refdb_backend__lookup(git_reference **out, git_refdb_backend *_backend, const char *ref_name)
{
	PGresult *result;
	git_oid oid;
	char *symlink;
	postgres_refdb_backend *backend;

	assert(ref_name && _backend);
	backend = (postgres_refdb_backend *) _backend;

	const int64_t repo_id = htonll(backend->repo_id);
	const char *paramValues[2] = {(char *)&repo_id, ref_name};
	int paramLengths[2] = {sizeof(repo_id), strlen(ref_name)};
	int paramFormats[2] = {1, 0};

	result = PQexecParams(backend->conn, "SELECT symlink, oid FROM " GIT_REFDB_TABLE_NAME " WHERE repo_id = $1 AND name = $2", 2, NULL, paramValues, paramLengths, paramFormats, 1);
	if (PQresultStatus(result) != PGRES_TUPLES_OK) {
		giterr_set_str(GITERR_REFERENCE, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	if (PQntuples(result) != 1) {
		PQclear(result);
		return GIT_ENOTFOUND;
	}

	symlink = PQgetvalue(result, 0, 0);
	if(strlen(symlink) > 0) {
		*out = git_reference__alloc_symbolic(ref_name, symlink);
	} else {
		git_oid_fromraw(&oid, (unsigned char *)PQgetvalue(result, 0, 1));
		*out = git_reference__alloc(ref_name, &oid, NULL);
	}

	PQclear(result);
	return GIT_OK;

}

int postgres_refdb_backend__iterator_next(git_reference **out, git_reference_iterator *_iter) {
	char* ref_name;
	char *symlink;
	git_oid oid;
	postgres_refdb_backend *backend;
	postgres_refdb_iterator *iter;

	assert(_iter);
	iter = (postgres_refdb_iterator *) _iter;

	if(iter->current >= PQntuples(iter->result))
		return GIT_ITEROVER;

	ref_name = PQgetvalue(iter->result, iter->current, 0);

	git_oid_fromraw(&oid, (unsigned char *)PQgetvalue(iter->result, iter->current++, 1));
	*out = git_reference__alloc(ref_name, &oid, NULL);

	return GIT_OK;
}

int postgres_refdb_backend__iterator_next_name(const char **ref_name, git_reference_iterator *_iter) {
	postgres_refdb_iterator *iter;

	assert(_iter);
	iter = (postgres_refdb_iterator *) _iter;

	if(iter->current >= PQntuples(iter->result))
		return GIT_ITEROVER;

	*ref_name = PQgetvalue(iter->result, iter->current++, 0);
	return GIT_OK;
}

void postgres_refdb_backend__iterator_free(git_reference_iterator *_iter) {
	postgres_refdb_iterator *iter;

	assert(_iter);
	iter = (postgres_refdb_iterator *) _iter;

	PQclear(iter->result);
	free(iter);
}

int postgres_refdb_backend__iterator(git_reference_iterator **_iter, struct git_refdb_backend *_backend, const char *glob)
{
	PGresult *result;
	char *pattern;
	char *current_pos;
	postgres_refdb_iterator *iterator;
	postgres_refdb_backend *backend;

	assert(_backend);
	backend = (postgres_refdb_backend *) _backend;

	const int64_t repo_id = htonll(backend->repo_id);

	iterator = calloc(1, sizeof(postgres_refdb_iterator));

	if(glob) {
		pattern = strcpy(malloc(strlen(glob) + 1), glob);
		current_pos = strchr(pattern, '%');
		for (char* p = current_pos; (current_pos = strchr(pattern, '*')) != NULL; *current_pos = '%');
		const char *paramValues[2] = {(char *) &repo_id, pattern};
		int paramLengths[2] = {sizeof(backend->repo_id), strlen(pattern)};
		int paramFormats[2] = {1, 0};
		result = PQexecParams(backend->conn, "SELECT name, oid FROM " GIT_REFDB_TABLE_NAME " WHERE repo_id = $1 AND symlink IS NULL AND name LIKE $2", 2, NULL, paramValues, paramLengths, paramFormats, 1);
	} else {
		const char *paramValues[1] = {(char *) &repo_id};
		int paramLengths[1] = {sizeof(repo_id)};
		int paramFormats[1] = {1};
		result = PQexecParams(backend->conn, "SELECT name, oid FROM " GIT_REFDB_TABLE_NAME " WHERE repo_id = $1 AND symlink IS NULL", 1, NULL, paramValues, paramLengths, paramFormats, 1);
	}

	if (PQresultStatus(result) != PGRES_TUPLES_OK) {
		giterr_set_str(GITERR_REFERENCE, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	iterator->backend = backend;
	iterator->current = 0;
	iterator->result = result;
	iterator->parent.next = &postgres_refdb_backend__iterator_next;
	iterator->parent.next_name = &postgres_refdb_backend__iterator_next_name;
	iterator->parent.free = &postgres_refdb_backend__iterator_free;

	*_iter = (git_reference_iterator *) iterator;

	return GIT_OK;
}

int postgres_refdb_backend__write(git_refdb_backend *_backend, const git_reference *ref, int force, const git_signature *who, const char *message, const git_oid *old, const char *old_target)
{

	PGresult *result;
	const char *name = git_reference_name(ref);
	const git_oid *target;
	const char *symbolic_target;
	postgres_refdb_backend *backend;

	assert(ref && _backend);
	backend = (postgres_refdb_backend *) _backend;

	target = git_reference_target(ref);
	symbolic_target = git_reference_symbolic_target(ref);

	const int64_t repo_id = htonll(backend->repo_id);
	if (target) {
		const char *paramValues[3] = {(char *)&repo_id, name, target->id};
		int paramLengths[3] = {sizeof(repo_id), strlen(name), 20};
		int paramFormats[3] = {1, 0, 1};
        if(force == 1) {
            result = PQexecParams(backend->conn, "INSERT INTO " GIT_REFDB_TABLE_NAME " VALUES($1, $2, NULL, $3) ON CONFLICT ON CONSTRAINT git_references_pkey DO UPDATE SET oid = $3, symlink = NULL", 3, NULL, paramValues, paramLengths, paramFormats, 0);
        } else {
            result = PQexecParams(backend->conn, "INSERT INTO " GIT_REFDB_TABLE_NAME " VALUES($1, $2, NULL, $3) ON CONFLICT ON CONSTRAINT git_references_pkey DO NOTHING", 3, NULL, paramValues, paramLengths, paramFormats, 0);
        }
	} else {
		const char *paramValues[3] = {(char *)&repo_id, name, symbolic_target};
		int paramLengths[3] = {sizeof(repo_id), strlen(name), strlen(symbolic_target)};
		int paramFormats[3] = {1, 0, 0};
        if(force == 1) {
            result = PQexecParams(backend->conn, "INSERT INTO " GIT_REFDB_TABLE_NAME " VALUES($1, $2, $3, NULL) ON CONFLICT ON CONSTRAINT git_references_pkey DO UPDATE SET symlink = $3, oid = NULL", 3, NULL, paramValues, paramLengths, paramFormats, 0);
        } else {
            result = PQexecParams(backend->conn, "INSERT INTO " GIT_REFDB_TABLE_NAME " VALUES($1, $2, $3, NULL) ON CONFLICT ON CONSTRAINT git_references_pkey DO NOTHING", 3, NULL, paramValues, paramLengths, paramFormats, 0);
        }
	}

	if(PQresultStatus(result) != PGRES_COMMAND_OK) {
		giterr_set_str(GITERR_REFERENCE, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	return GIT_OK;
}

int postgres_refdb_backend__rename(git_reference **out, git_refdb_backend *_backend, const char *old_name, const char *new_name, int force, const git_signature *who, const char *message)
{
	PGresult *result;
	postgres_refdb_backend *backend;

	assert(old_name && new_name && _backend);
	backend = (postgres_refdb_backend *) _backend;

	const int64_t repo_id = htonll(backend->repo_id);
	const char *paramValues[3] = {new_name, (char *) &repo_id, old_name};
	int paramLengths[3] = {strlen(new_name), sizeof(repo_id), strlen(old_name)};
	int paramFormats[3] = {0, 1, 0};

	result = PQexecParams(backend->conn, "UPDATE " GIT_REFDB_TABLE_NAME " SET name = $1 WHERE repo_id = $2 AND name = $3", 3, NULL, paramValues, paramLengths, paramFormats, 0);
	if(PQresultStatus(result) != PGRES_COMMAND_OK) {
		giterr_set_str(GITERR_REFERENCE, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	return postgres_refdb_backend__lookup(out, _backend, new_name);
}

int postgres_refdb_backend__del(git_refdb_backend *_backend, const char *ref_name, const git_oid *old, const char *old_target)
{
	PGresult *result;
	postgres_refdb_backend *backend;

	assert(ref_name && _backend);
	backend = (postgres_refdb_backend *) _backend;

	const int64_t repo_id = htonll(backend->repo_id);
	const char *paramValues[2] = {(char *) &repo_id, ref_name};
	int paramLengths[2] = {sizeof(repo_id), strlen(ref_name)};
	int paramFormats[3] = {1, 0};

	result = PQexecParams(backend->conn, "DELETE FROM " GIT_REFDB_TABLE_NAME " WHERE repo_id = $1 AND name = $2", 2, NULL, paramValues, paramLengths, paramFormats, 0);
	if(PQresultStatus(result) != PGRES_COMMAND_OK) {
		giterr_set_str(GITERR_REFERENCE, PQerrorMessage(backend->conn));
		return GIT_ERROR;
	}

	return GIT_OK;
}

void postgres_refdb_backend__free(git_refdb_backend *_backend)
{
	postgres_odb_backend *backend;

	assert(_backend);
	backend = (postgres_refdb_backend *)_backend;

	PQfinish(backend->conn);

	free(backend);
}

int postgres_refdb_backend__has_log(git_refdb_backend *_backend, const char *refname)
{
	return 0;
}

int postgres_refdb_backend__ensure_log(git_refdb_backend *_backend, const char *refname)
{
	return GIT_ERROR;
}

int postgres_refdb_backend__reflog_read(git_reflog **out, git_refdb_backend *_backend, const char *name)
{
	return GIT_ERROR;
}

int postgres_refdb_backend__reflog_write(git_refdb_backend *_backend, git_reflog *reflog)
{
	return GIT_ERROR;
}

int postgres_refdb_backend__reflog_rename(git_refdb_backend *_backend, const char *old_name, const char *new_name)
{
	return GIT_ERROR;
}

int postgres_refdb_backend__reflog_delete(git_refdb_backend *_backend, const char *name)
{
	return GIT_ERROR;
}

int pq_connect(PGconn **conn, const char *conn_info)
{
	*conn = PQconnectdb(conn_info);
	if(!(*conn)) {
		return 1;
	}

	if(PQstatus(*conn) != CONNECTION_OK) {
		PQfinish(*conn);
		return 1;
	}

	return 0;
}

int git_odb_backend_postgres(git_odb_backend **backend_out, PGconn *conn, int64_t repo_id)
{
	postgres_odb_backend *backend;

	backend = calloc(1, sizeof (postgres_odb_backend));
	if (backend == NULL)
		return GITERR_NOMEMORY;

	backend->conn = conn;
	backend->repo_id = repo_id;
	backend->parent.version = 1;
	backend->parent.read = &postgres_odb_backend__read;
	backend->parent.read_prefix = &postgres_odb_backend__read_prefix;
	backend->parent.read_header = &postgres_odb_backend__read_header;
	backend->parent.exists = &postgres_odb_backend__exists;
	backend->parent.write = &postgres_odb_backend__write;
	backend->parent.free = &postgres_odb_backend__free;
	backend->parent.writestream = NULL;
	backend->parent.foreach = NULL;

	*backend_out = (git_odb_backend *) backend;

	return GIT_OK;
}

int git_refdb_backend_postgres(git_refdb_backend **backend_out, PGconn *conn, int64_t repo_id)
{
	postgres_refdb_backend *backend;

	backend = calloc(1, sizeof(postgres_refdb_backend));
	if (backend == NULL)
		return GITERR_NOMEMORY;

	backend->conn = conn;
	backend->repo_id = repo_id;
	backend->parent.exists = &postgres_refdb_backend__exists;
	backend->parent.lookup = &postgres_refdb_backend__lookup;
	backend->parent.iterator = &postgres_refdb_backend__iterator;
	backend->parent.write = &postgres_refdb_backend__write;
	backend->parent.del = &postgres_refdb_backend__del;
	backend->parent.rename = &postgres_refdb_backend__rename;
	backend->parent.compress = NULL;
	backend->parent.free = &postgres_refdb_backend__free;

	backend->parent.has_log = &postgres_refdb_backend__has_log;
	backend->parent.ensure_log = &postgres_refdb_backend__ensure_log;
	backend->parent.reflog_read = &postgres_refdb_backend__reflog_read;
	backend->parent.reflog_write = &postgres_refdb_backend__reflog_write;
	backend->parent.reflog_rename = &postgres_refdb_backend__reflog_rename;
	backend->parent.reflog_delete = &postgres_refdb_backend__reflog_delete;

	*backend_out = (git_refdb_backend *) backend;

	return GIT_OK;
}
