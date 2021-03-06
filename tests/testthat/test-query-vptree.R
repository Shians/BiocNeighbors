# Tests queryVptree().
# library(BiocNeighbors); library(testthat); source("test-query-vptree.R")

library(FNN)
set.seed(1001)
test_that("queryVptree() behaves correctly with queries", {
    ndata <- 1000
    nquery <- 100

    for (ndim in c(1, 5, 10, 20)) {
        for (k in c(1, 5, 20)) { 
            X <- matrix(runif(ndata * ndim), nrow=ndata)
            Y <- matrix(runif(nquery * ndim), nrow=nquery)

            out <- queryVptree(X, k=k, query=Y)
            ref <- get.knnx(data=X, query=Y, k=k)
            expect_identical(out$index, ref$nn.index)
            expect_equal(out$distance, ref$nn.dist)
        }
    }
})

set.seed(1002)
test_that("queryVptree() works correctly with subsetting", {
    nobs <- 1000
	nquery <- 93
    ndim <- 21
    k <- 7

    X <- matrix(runif(nobs * ndim), nrow=nobs)
	Y <- matrix(runif(nquery * ndim), nrow=nquery)
    ref <- queryVptree(X, Y, k=k)

    i <- sample(nquery, 20)
    sub <- queryVptree(X, Y, k=k, subset=i)
    expect_identical(sub$index, ref$index[i,,drop=FALSE])
    expect_identical(sub$distance, ref$distance[i,,drop=FALSE])

    i <- rbinom(nquery, 1, 0.5) == 0L
    sub <- queryVptree(X, Y, k=k, subset=i)
    expect_identical(sub$index, ref$index[i,,drop=FALSE])
    expect_identical(sub$distance, ref$distance[i,,drop=FALSE])

    rownames(Y) <- paste0("CELL", seq_len(nquery))
    i <- sample(rownames(Y), 50)
    sub <- queryVptree(X, Y, k=k, subset=i)
    m <- match(i, rownames(Y))
    expect_identical(sub$index, ref$index[m,,drop=FALSE])
    expect_identical(sub$distance, ref$distance[m,,drop=FALSE])
})

set.seed(1003)
test_that("queryVptree() behaves correctly with alternative options", {
    nobs <- 1000
    nquery <- 100
    ndim <- 10
    k <- 5

    X <- matrix(runif(nobs * ndim), nrow=nobs)
    Y <- matrix(runif(nquery * ndim), nrow=nquery)
    out <- queryVptree(X, Y, k=k)
    
    # Checking what we extract.
    out2 <- queryVptree(X, Y, k=k, get.distance=FALSE)
    expect_identical(out2$distance, NULL)
    expect_identical(out2$index, out$index)

    out3 <- queryVptree(X, Y, k=k, get.index=FALSE)
    expect_identical(out3$index, NULL)
    expect_identical(out3$distance, out$distance)
  
    # Checking precomputation.
    pre <- buildVptree(X)
    out4 <- queryVptree(query=Y, k=k, precomputed=pre) # no need for X!
    expect_identical(out4, out)

    # Checking transposition.
    out5 <- queryVptree(X, k=k, query=t(Y), transposed=TRUE)
    expect_identical(out5, out)
})

set.seed(100301)
test_that("queryVptree() behaves correctly with parallelization", {
    nobs <- 1000
    nquery <- 124
    ndim <- 10
    k <- 5

    X <- matrix(runif(nobs * ndim), nrow=nobs)
    Y <- matrix(runif(nquery * ndim), nrow=nquery)
    out <- queryVptree(X, Y, k=k)
  
    # Trying out different types of parallelization.
    out1 <- queryVptree(X, Y, k=k, BPPARAM=MulticoreParam(2))
    expect_identical(out$index, out1$index)
    expect_identical(out$distance, out1$distance)

    out2 <- queryVptree(X, Y, k=k, BPPARAM=SnowParam(3))
    expect_identical(out$index, out2$index)
    expect_identical(out$distance, out2$distance)
})

set.seed(10031)
test_that("queryVptree() raw output behaves correctly", {
    nobs <- 1001
    nquery <- 101
    ndim <- 11
    k <- 7
    X <- matrix(runif(nobs * ndim), nrow=nobs)
  	Y <- matrix(runif(nquery * ndim), nrow=nquery)
 
    pre <- buildVptree(X)
    out <- queryVptree(query=Y, k=k, precomputed=pre, raw.index=TRUE)
    ref <- queryVptree(query=Y, X=t(bndata(pre)), k=k)
    expect_identical(out, ref)

    # Behaves with subsetting.
    i <- sample(nquery, 20)
    out <- queryVptree(query=Y, k=k, precomputed=pre, raw.index=TRUE, subset=i)
    ref <- queryVptree(query=Y, X=t(bndata(pre)), k=k, subset=i)
    expect_identical(out, ref)

    i <- rbinom(nquery, 1, 0.5) == 0L
    out <- queryVptree(query=Y, k=k, precomputed=pre, raw.index=TRUE, subset=i)
    ref <- queryVptree(query=Y, X=t(bndata(pre)), k=k, subset=i)
    expect_identical(out, ref)

    # Adding row names.
    rownames(Y) <- paste0("CELL", seq_len(nquery))
    i <- sample(rownames(Y), 30)
    out <- queryVptree(query=Y, k=k, precomputed=pre, raw.index=TRUE, subset=i)
    ref <- queryVptree(query=Y, X=t(bndata(pre)), k=k, subset=i)
    expect_identical(out, ref)
})

set.seed(1004)
test_that("queryVptree() behaves correctly with silly inputs", {
    nobs <- 1000
	nquery <- 100
    ndim <- 10
    X <- matrix(runif(nobs * ndim), nrow=nobs)
    Y <- matrix(runif(nquery * ndim), nrow=nquery)
    
    # What happens when k is not positive.
    expect_error(queryVptree(X, Y, k=0), "positive")
    expect_error(queryVptree(X, Y, k=-1), "positive")

    # What happens when there are more NNs than k.
    restrict <- 10
    expect_warning(out <- queryVptree(X[seq_len(restrict),], Y, k=20), "capped")
    expect_warning(ref <- queryVptree(X[seq_len(restrict),], Y, k=restrict), NA)
    expect_equal(out, ref)

    # What happens when there are no dimensions.
    out <- queryVptree(X[,0], Y[,0], k=20)
    expect_identical(nrow(out$index), as.integer(nquery))
    expect_identical(ncol(out$index), 20L)
    expect_identical(dim(out$index), dim(out$distance))
    expect_true(all(out$distance==0))

    # What happens when the query is of a different dimension.
    Z <- matrix(runif(nobs * ndim * 2), nrow=nobs)
    expect_error(queryVptree(X, k=20, query=Z), "dimensionality")

    # What happens when we request raw.index without precomputed.
    expect_error(queryVptree(X, Y, k=20, raw.index=TRUE), "not valid")

    # What happens when the query is not, strictly a matrix.
    AA <- data.frame(Y)
    colnames(AA) <- NULL
    expect_equal(queryVptree(X, Y, k=20), queryVptree(X, AA, k=20))
})
