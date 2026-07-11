package com.pulse.federation;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class FederatedAggregationService {

    private final GradientUpdateRepository repository;

    private static final int MIN_DEVICES_FOR_AGGREGATION = 3;

    public GradientUpdate saveUpdate(GradientUpdate update) {
        GradientUpdate saved = repository.save(update);
        long count = repository.countByRoundId(update.getRoundId());
        log.info("Round {}: received update from device {}. Total this round: {}",
                update.getRoundId(), update.getDeviceId(), count);

        if (count >= MIN_DEVICES_FOR_AGGREGATION) {
            Map<String, Double> aggregated = runFedAvg(update.getRoundId());
            log.info("Round {} complete. FedAvg result: {}", update.getRoundId(), aggregated);
        }

        return saved;
    }

    // FedAvg: simple average of all category deltas across devices in this round
    public Map<String, Double> runFedAvg(String roundId) {
        List<GradientUpdate> updates = repository.findByRoundId(roundId);
        if (updates.isEmpty()) return Map.of();

        Map<String, Double> sumDeltas = new HashMap<>();
        Map<String, Integer> counts = new HashMap<>();

        for (GradientUpdate update : updates) {
            update.getCategoryDeltas().forEach((category, delta) -> {
                sumDeltas.merge(category, delta, Double::sum);
                counts.merge(category, 1, Integer::sum);
            });
        }

        Map<String, Double> averaged = new HashMap<>();
        sumDeltas.forEach((cat, sum) ->
                averaged.put(cat, sum / counts.getOrDefault(cat, 1)));

        return averaged;
    }

    public Map<String, Object> getRoundStats(String roundId) {
        long count = repository.countByRoundId(roundId);
        return Map.of(
                "roundId", roundId,
                "deviceCount", count,
                "aggregationReady", count >= MIN_DEVICES_FOR_AGGREGATION
        );
    }
}
