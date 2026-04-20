package br.gov.prefeiturajardelalves.portal.common.dto;

import java.util.Locale;
import java.util.Map;

public record FilterRequest(
        String search,
        Map<String, Object> filters,
        int page,
        int size,
        String sortBy,
        String sortDirection
) {
    private static final int DEFAULT_SIZE = 20;
    private static final int MAX_SIZE = 100;

    public FilterRequest {
        filters = filters == null ? Map.of() : Map.copyOf(filters);
        page = Math.max(page, 0);
        size = size <= 0 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
        sortDirection = normalizeSortDirection(sortDirection);
    }

    private static String normalizeSortDirection(String direction) {
        if (direction == null || direction.isBlank()) {
            return "ASC";
        }

        String normalized = direction.toUpperCase(Locale.ROOT);
        return "DESC".equals(normalized) ? "DESC" : "ASC";
    }
}
