package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/require"
)

func metricsMuxStatus(t *testing.T, enablePprof bool, path string) int {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	newMetricsMux(enablePprof).ServeHTTP(rec, req)
	return rec.Code
}

func TestMetricsMuxServesMetricsWithoutPprof(t *testing.T) {
	require.Equal(t, http.StatusOK, metricsMuxStatus(t, false, "/metrics"))
	require.Equal(t, http.StatusNotFound, metricsMuxStatus(t, false, "/debug/pprof/"))
	require.Equal(t, http.StatusNotFound, metricsMuxStatus(t, false, "/debug/pprof/heap"))
}

func TestMetricsMuxServesPprofWhenEnabled(t *testing.T) {
	require.Equal(t, http.StatusOK, metricsMuxStatus(t, true, "/metrics"))
	require.Equal(t, http.StatusOK, metricsMuxStatus(t, true, "/debug/pprof/"))
	require.Equal(t, http.StatusOK, metricsMuxStatus(t, true, "/debug/pprof/heap"))
	require.Equal(t, http.StatusOK, metricsMuxStatus(t, true, "/debug/pprof/goroutine?debug=1"))
}
