package br.gov.prefeiturajardelalves.portal.status;

import java.time.Instant;
import java.util.Map;

import br.gov.prefeiturajardelalves.portal.common.dto.ApiResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.info.BuildProperties;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class StatusController {
    private final String applicationName;
    private final BuildProperties buildProperties;

    public StatusController(
            @Value("${spring.application.name:portal-prefeitura}") String applicationName,
            ObjectProvider<BuildProperties> buildProperties
    ) {
        this.applicationName = applicationName;
        this.buildProperties = buildProperties.getIfAvailable();
    }

    @GetMapping("/")
    public ApiResponse<Map<String, Object>> index() {
        return status();
    }

    @GetMapping("/status")
    public ApiResponse<Map<String, Object>> status() {
        return ApiResponse.success(Map.of(
                "application", applicationName,
                "version", buildProperties == null ? "dev" : buildProperties.getVersion(),
                "status", "UP",
                "timestamp", Instant.now().toString()
        ));
    }
}
