#' @export
#' @importFrom BiocParallel SerialParam bpmapply
queryAnnoy <- function(X, query, k, get.index=TRUE, get.distance=TRUE, BPPARAM=SerialParam(), precomputed=NULL, transposed=FALSE, subset=NULL, ...)
# Identifies nearest neighbours in 'X' from a query set.
#
# written by Aaron Lun
# created 19 June 2018
{
    if (is.null(precomputed)) {
        precomputed <- buildAnnoy(X, ...)
        on.exit(unlink(AnnoyIndex_path(precomputed)))
    }

    k <- .refine_k(k, precomputed, query=TRUE)

    q.out <- .setup_query(query, transposed, subset)
    query <- q.out$query        
    job.id <- q.out$index
    reorder <- q.out$reorder

    # Dividing jobs up for NN finding.
    jobs <- .assign_jobs(job.id - 1L, BPPARAM)
    collected <- bpmapply(jobs, FUN=.query_annoy,
        MoreArgs=list(ndims=ncol(precomputed),
			fname=AnnoyIndex_path(precomputed),
            k=k,
            query=query,
            get.index=get.index, 
            get.distance=get.distance), 
        BPPARAM=BPPARAM, SIMPLIFY=FALSE)

    # Aggregating results across cores.
    output <- list()
    if (get.index) {
        neighbors <- .combine_matrices(collected, i=1, reorder=reorder)
        output$index <- neighbors
    } 
    if (get.distance) {
        output$distance <- .combine_matrices(collected, i=2, reorder=reorder)
    }
    return(output)
}

.query_annoy <- function(jobs, query, ndims, fname, k, get.index, get.distance) {
    .Call(cxx_query_annoy, jobs, query, ndims, fname, k, get.index, get.distance)
}
