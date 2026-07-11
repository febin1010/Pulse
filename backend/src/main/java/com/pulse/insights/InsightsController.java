package com.pulse.insights;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/insights")
@RequiredArgsConstructor
public class InsightsController {

    private final InsightsService insightsService;

    @PostMapping
    public ResponseEntity<Map<String, String>> getInsights(@Valid @RequestBody FeatureVector vector) {
        String insights = insightsService.generateInsights(vector);
        return ResponseEntity.ok(Map.of("insights", insights));
    }
}
