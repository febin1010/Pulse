package com.pulse.federation;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/federation")
@RequiredArgsConstructor
public class FederatedAggregationController {

    private final FederatedAggregationService service;

    @PostMapping("/gradient")
    public ResponseEntity<Map<String, Object>> submitGradient(@RequestBody GradientUpdate update) {
        GradientUpdate saved = service.saveUpdate(update);
        return ResponseEntity.ok(Map.of(
                "id", saved.getId(),
                "status", "received",
                "roundId", saved.getRoundId()
        ));
    }

    @GetMapping("/round/{roundId}/stats")
    public ResponseEntity<Map<String, Object>> getRoundStats(@PathVariable String roundId) {
        return ResponseEntity.ok(service.getRoundStats(roundId));
    }
}
