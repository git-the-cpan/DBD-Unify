/* Relentlessly copied from DBD-Oracle (one has to start somewhere ...) */

#if defined(get_no_modify) && !defined(no_modify)
# define no_modify PL_no_modify
# endif

/* I really like this one in perl ... */
#define	unless(e)	if (!(e))

/* ====== Include Unify Header Files ====== */

#include <dbtypes.h>
#include <fdesc.h>

/* ------ end of Unify include files ------ */


/* ====== define data types ====== */

typedef struct imp_fbh_st imp_fbh_t;

struct imp_drh_st {
    dbih_drc_t com;		/* MUST be first element in structure	*/
    };

/* Define dbh implementor data structure */
struct imp_dbh_st {
    dbih_dbc_t com;		/* MUST be first element in structure	*/

#ifdef OCI_V8_SYNTAX
    OCIEnv     *envhp;		/* copy of drh pointer	*/
    OCIError   *errhp;
    OCIServer  *srvhp;
    OCISvcCtx  *svchp;
    OCISession *authp;
#endif

    int        RowCacheSize;
    };

/* Define sth implementor data structure */
struct imp_sth_st {
    dbih_stc_t  com;		/* MUST be first element in structure	*/

#ifdef OCI_V8_SYNTAX
    OCIEnv     *envhp;		/* copy of dbh pointer	*/
    OCIError   *errhp;		/* copy of dbh pointer	*/
    OCIServer  *srvhp;		/* copy of dbh pointer	*/
    OCISvcCtx  *svchp;		/* copy of dbh pointer	*/
    OCIStmt    *stmhp;
    ub2 	stmt_type;	/* OCIAttrGet OCI_ATTR_STMT_TYPE	*/
    U16		auto_lob;
    int  	has_lobs;
#endif
    int  	disable_finish; /* fetched cursors can core dump in finish */

    /* Input Details	*/
    char       *statement;	/* sql (see sth_scan)		*/
    HV         *all_params_hv;	/* all params, keyed by name	*/
    AV         *out_params_av;	/* quick access to inout params	*/

    /* Select Column Output Details	*/
    int         done_desc;   /* have we described this sth yet ?	*/
    imp_fbh_t  *fbh;	    /* array of imp_fbh_t structs	*/
    char       *fbh_cbuf;    /* memory for all field names       */
    int         t_dbsize;     /* raw data width of a row		*/
    IV          long_readlen; /* local copy to handle oraperl	*/

    /* Select Row Cache Details */
    int         cache_rows;
    int         in_cache;
    int         next_entry;
    int         eod_errno;
    int         est_width;    /* est'd avg row width on-the-wire	*/

    /* (In/)Out Parameter Details */
    bool        has_inout_params;
    };
#define IMP_STH_EXECUTING	0x0001

typedef struct fb_ary_st fb_ary_t;    /* field buffer array	*/
struct fb_ary_st { 	/* field buffer array EXPERIMENTAL	*/
#ifdef OCI_V8_SYNTAX
    ub2  bufl;		/* length of data buffer		*/
    sb2  *aindp;	/* null/trunc indicator variable	*/
    ub1  *abuf;		/* data buffer (points to sv data)	*/
    ub2  *arlen;	/* length of returned data		*/
    ub2  *arcode;	/* field level error status		*/
#else
    short bufl;	/* Filler for now ... */
#endif
    };

struct imp_fbh_st { 	/* field buffer EXPERIMENTAL */
    imp_sth_t *imp_sth;	/* 'parent' statement	*/
    int field_num;	/* 0..n-1		*/

    /* Oracle's description of the field	*/
#ifdef OCI_V8_SYNTAX
    OCIParam  *parmdp;
    OCIDefine *defnp;
    void *desc_h;	/* descriptor if needed (LOBs etc)	*/
    ub4   desc_t;	/* OCI type of descriptorh		*/
    int  (*fetch_func) _((SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv));
    ub2  dbsize;
    ub2  dbtype;	/* actual type of field (see ftype)	*/
    ub2  prec;		/* XXX docs say ub1 but ub2 is needed	*/
    sb1  scale;
    ub1  nullok;
    void *special;	/* hook for special purposes (LOBs etc)	*/
#endif
    SV   *name_sv;	/* only set for OCI8			*/
    char *name;
#ifdef OCI_V8_SYNTAX
    sb4  disize;	/* max display/buffer size		*/
#endif

    /* Our storage space for the field data as it's fetched	*/
#ifdef OCI_V8_SYNTAX
    sword ftype;	/* external datatype we wish to get	*/
#endif
    fb_ary_t *fb_ary;	/* field buffer array			*/
    };

typedef struct phs_st phs_t;    /* scalar placeholder   */

struct phs_st {  	/* scalar placeholder EXPERIMENTAL	*/
    imp_sth_t *imp_sth; /* 'parent' statement  			*/
#ifdef OCI_V8_SYNTAX
    sword ftype;	/* external OCI field type		*/
#endif

    SV	*sv;		/* the scalar holding the value		*/
    int sv_type;	/* original sv type at time of bind	*/
    bool is_inout;

    IV  maxlen;		/* max possible len (=allocated buffer)	*/
#ifdef OCI_V8_SYNTAX
    sb4 maxlen_bound;	/* and Oracle bind has been called	*/

    OCIBind *bndhp;
    void *desc_h;	/* descriptor if needed (LOBs etc)	*/
    ub4   desc_t;	/* OCI type of desc_h			*/
    ub4   alen;
    ub2 arcode;

    sb2 indp;		/* null indicator			*/
#endif
    char *progv;

    int (*out_prepost_exec)_((SV *, imp_sth_t *, phs_t *, int pre_exec));
    SV	*ora_field;	/* from attribute (for LOB binds)	*/
    int alen_incnull;	/* 0 or 1 if alen should include null	*/
    char name[1];	/* struct is malloc'd bigger as needed	*/
    };


/* ------ define functions and external variables ------ */

extern int ora_fetchtest;

void dbd_init_oci _((dbistate_t *dbistate));
void dbd_preparse _((imp_sth_t *imp_sth, char *statement));
void dbd_fbh_dump _((imp_fbh_t *fbh, int i, int aidx));
void ora_free_fbh_contents _((imp_fbh_t *fbh));
int ora_dbtype_is_long _((int dbtype));
int calc_cache_rows _((int num_fields, int est_width, int cache_rows, int has_longs));
fb_ary_t *fb_ary_alloc _((int bufl, int size));
int ora_db_reauthenticate _((SV *dbh, imp_dbh_t *imp_dbh, char *uid, char *pwd));

#define OTYPE_IS_LONG(t)  ((t)==8 || (t)==24 || (t)==94 || (t)==95)

#ifdef OCI_V8_SYNTAX

int oci_error _((SV *h, OCIError *errhp, sword status, char *what));
char *oci_stmt_type_name _((int stmt_type));
char *oci_status_name _((sword status));
int dbd_rebind_ph_lob _((SV *sth, imp_sth_t *imp_sth, phs_t *phs));
void ora_free_lob_refetch _((SV *sth, imp_sth_t *imp_sth));
int post_execute_lobs _((SV *sth, imp_sth_t *imp_sth, ub4 row_count));
ub4 ora_parse_uid _((imp_dbh_t *imp_dbh, char **uidp, char **pwdp));
char *ora_sql_error _((imp_sth_t *imp_sth, char *msg));

sb4 dbd_phs_in _((dvoid *octxp, OCIBind *bindp, ub4 iter, ub4 index,
              dvoid **bufpp, ub4 *alenp, ub1 *piecep, dvoid **indpp));
sb4 dbd_phs_out _((dvoid *octxp, OCIBind *bindp, ub4 iter, ub4 index,
             dvoid **bufpp, ub4 **alenpp, ub1 *piecep,
             dvoid **indpp, ub2 **rcodepp));
int dbd_rebind_ph_rset _((SV *sth, imp_sth_t *imp_sth, phs_t *phs));

#endif /* OCI_V8_SYNTAX */

/*
#include "ocitrace.h"
*/

/* These defines avoid name clashes for multiple statically linked DBD's	*/

#define dbd_init            uni_init
#define dbd_db_login        uni_db_login
#define dbd_db_do           uni_db_do
#define dbd_db_commit       uni_db_commit
#define dbd_db_rollback     uni_db_rollback
#define dbd_db_disconnect   uni_db_disconnect
#define dbd_db_destroy      uni_db_destroy
#define dbd_db_STORE_attrib uni_db_STORE_attrib
#define dbd_db_FETCH_attrib uni_db_FETCH_attrib
#define dbd_st_prepare      uni_st_prepare
#define dbd_st_rows         uni_st_rows
#define dbd_st_execute      uni_st_execute
#define dbd_st_fetch        uni_st_fetch
#define dbd_st_finish       uni_st_finish
#define dbd_st_destroy      uni_st_destroy
#define dbd_st_blob_read    uni_st_blob_read
#define dbd_st_STORE_attrib uni_st_STORE_attrib
#define dbd_st_FETCH_attrib uni_st_FETCH_attrib
#define dbd_describe        uni_describe
#define dbd_bind_ph         uni_bind_ph

/* end */
