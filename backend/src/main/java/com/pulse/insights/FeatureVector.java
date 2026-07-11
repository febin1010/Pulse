package com.pulse.insights;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class FeatureVector {

    @NotBlank
    private String deviceId;

    @NotNull
    private Double avgWeeklySpend;

    @NotBlank
    private String topCategory;

    private int anomalyCount;
    private boolean projectedDeficit;
    private double deficitAmount;

    @NotBlank
    private String spendingTrend;   // "increasing", "stable", "decreasing"
}
