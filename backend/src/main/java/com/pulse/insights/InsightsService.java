package com.pulse.insights;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Service
@Slf4j
public class InsightsService {

    @Value("${groq.api.key}")
    private String apiKey;

    @Value("${pulse.insights.max-calls-per-day:10}")
    private int maxCallsPerDay;

    private final Map<String, AtomicInteger> callCounts = new ConcurrentHashMap<>();

    private final RestClient restClient = RestClient.builder()
            .baseUrl("https://api.groq.com/openai/v1")
            .build();

    public String generateInsights(FeatureVector vector) {
        if (!checkRateLimit(vector.getDeviceId())) {
            return "You've reached your daily insight limit. Check back tomorrow for fresh insights.";
        }

        try {
            Map<String, Object> body = Map.of(
                    "model", "llama-3.1-8b-instant",
                    "max_tokens", 200,
                    "messages", List.of(
                            Map.of("role", "user", "content", buildPrompt(vector))
                    )
            );

            Map response = restClient.post()
                    .uri("/chat/completions")
                    .header("Authorization", "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(Map.class);

            List choices = (List) response.get("choices");
            Map choice = (Map) choices.get(0);
            Map message = (Map) choice.get("message");
            return (String) message.get("content");

        } catch (Exception e) {
            log.error("Groq API call failed: {}", e.getMessage());
            return "Insights temporarily unavailable. Please try again later.";
        }
    }

    private String buildPrompt(FeatureVector v) {
        StringBuilder sb = new StringBuilder();
        sb.append("A user's anonymized weekly spending summary:\n");
        sb.append(String.format("- Average weekly spend: ₹%.0f\n", v.getAvgWeeklySpend()));
        sb.append(String.format("- Top spending category: %s\n", v.getTopCategory()));
        sb.append(String.format("- Unusual transactions flagged: %d\n", v.getAnomalyCount()));
        sb.append(String.format("- Spending trend: %s\n", v.getSpendingTrend()));

        if (v.isProjectedDeficit()) {
            sb.append(String.format("- Projected to overspend by: ₹%.0f this month\n", v.getDeficitAmount()));
        }

        sb.append("\nWrite exactly 2 short, specific, actionable financial insights.");
        sb.append(" Each must be under 35 words. Be direct and personal.");
        sb.append(" No generic advice. No bullet points. Separate with a newline.");
        sb.append(" Amounts in Indian Rupees (₹).");

        return sb.toString();
    }

    private boolean checkRateLimit(String deviceId) {
        AtomicInteger count = callCounts.computeIfAbsent(deviceId, k -> new AtomicInteger(0));
        return count.incrementAndGet() <= maxCallsPerDay;
    }
}
