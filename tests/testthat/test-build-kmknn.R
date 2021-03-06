# Tests buildKmknn().
# library(BiocNeighbors); library(testthat); source("test-build-kmknn.R")

set.seed(20000)
test_that("buildKmknn() works as expected", {
    for (ndim in c(1, 5, 10, 20)) {
        for (nobs in c(500, 1000, 2000)) { 
            X <- matrix(runif(nobs * ndim), nrow=nobs)
            
            out <- buildKmknn(X)
            expect_identical(dim(out), dim(X))
            expect_identical(rev(dim(bndata(out))), dim(X))
            expect_identical(sort(bnorder(out)), seq_len(nobs))
            expect_identical(bndata(out), t(X[bnorder(out),]))

            Nclust <- length(KmknnIndex_cluster_info(out))
            expect_identical(Nclust, as.integer(ceiling(sqrt(nobs))))

            accounted <- logical(nobs)
            unsorted <- !logical(Nclust)
            collected <- vector("list", Nclust)

            for (i in seq_along(KmknnIndex_cluster_info(out))) {
                current <- KmknnIndex_cluster_info(out)[[i]]
                unsorted[i] <- is.unsorted(current[[2]])

                idx <- current[[1]] + seq_along(current[[2]])
                expect_true(!any(accounted[idx]))
                accounted[idx] <- TRUE

                collected[[i]] <- rowMeans(bndata(out)[,idx,drop=FALSE]) 
            }

            expect_true(all(accounted))
            expect_true(!any(unsorted))
            expect_equal(do.call(cbind, collected), unname(KmknnIndex_cluster_centers(out)), tol=1e-4) # Oddly inaccurate, for some reason...
        }
    }
})

set.seed(200001)
test_that("buildKmknn() preserves dimension names", {
    nobs <- 1011
    ndim <- 23
    X <- matrix(runif(nobs * ndim), nrow=nobs)
    rownames(X) <- paste0("POINT", seq_len(nobs))
    colnames(X) <- paste0("DIM", seq_len(ndim))

    out <- buildKmknn(X)
    expect_identical(rownames(out), rownames(X))
    expect_identical(rownames(bndata(out)), colnames(X))
    expect_identical(colnames(bndata(out)), rownames(X)[bnorder(out)])

    # Still true if there are no cells.
    out <- buildKmknn(X[0,,drop=FALSE])
    expect_identical(rownames(bndata(out)), colnames(X))
    expect_identical(colnames(bndata(out)), NULL)
    expect_identical(rownames(out), NULL)
})

set.seed(200002)
test_that("buildKmknn() responds to transposition", {
    nobs <- 1011
    ndim <- 10
    X <- matrix(runif(nobs * ndim), nrow=nobs)
    rownames(X) <- paste0("POINT", seq_len(nobs))
    colnames(X) <- paste0("DIM", seq_len(ndim))

    set.seed(101)
    ref <- buildKmknn(X)
    set.seed(101)
    out <- buildKmknn(t(X), transposed=TRUE)
    expect_identical(ref, out)

    # Check it works in a function.
    ref <- findKmknn(X, k=5)
    out <- findKmknn(t(X), k=5, transposed=TRUE)
    expect_identical(ref, out)
})

set.seed(20001)
test_that("buildKmknn() behaves sensibly with silly inputs", {
    nobs <- 100L
    ndim <- 10L
    X <- matrix(runif(nobs * ndim), nrow=nobs)

    # What happens when there are no cells.
    out <- buildKmknn(X[0,,drop=FALSE])
    expect_identical(dim(bndata(out)), c(ndim, 0L))
    expect_identical(dim(KmknnIndex_cluster_centers(out)), c(ndim, 0L))
    expect_identical(length(KmknnIndex_cluster_info(out)), 0L)
    expect_identical(length(bnorder(out)), 0L)

    # What happens when there are no dimensions.
    out <- buildKmknn(X[,0,drop=FALSE])
    expect_identical(dim(bndata(out)), c(0L, nobs))
    expect_identical(dim(KmknnIndex_cluster_centers(out)), c(0L, 1L))
    expect_identical(length(KmknnIndex_cluster_info(out)), 1L)
    expect_identical(KmknnIndex_cluster_info(out)[[1]][[1]], 0L)
    expect_identical(KmknnIndex_cluster_info(out)[[1]][[2]], numeric(nobs))
    expect_identical(bnorder(out), seq_len(nobs))

    # Checking that it behaves without distinct data points.
    expect_error(prec <- buildKmknn(matrix(0, 10,10)), NA)

    # We get the same result when 'X' is not, strictly, a matrix.
    set.seed(1999)
    ref <- buildKmknn(X)
    set.seed(1999)
    Y <- data.frame(X, check.names=FALSE, fix.empty.names=FALSE)
    colnames(Y) <- NULL
    out <- buildKmknn(Y)
    expect_equal(ref, out)
})
