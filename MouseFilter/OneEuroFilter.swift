import Foundation

class LowPassFilter {
    private var alpha: Double
    private var y: Double?
    private var s: Double?
    
    init(alpha: Double) {
        precondition(alpha > 0 && alpha <= 1.0, "alpha (\(alpha)) should be in (0.0, 1.0]")
        self.alpha = alpha
    }
    
    func filter(value: Double, timestamp: Double? = nil, alpha: Double? = nil) -> Double {
        if let newAlpha = alpha { self.alpha = newAlpha }
        let filtered = y == nil ? value : self.alpha * value + (1.0 - self.alpha) * (s ?? 0.0)
        y = value
        s = filtered
        return filtered
    }
    
    func lastValue() -> Double? { y }
    func lastFilteredValue() -> Double? { s }
    func reset() { y = nil; s = nil }
}

class OneEuroFilter {
    private var freq: Double
    private var mincutoff: Double
    private var beta: Double
    private var dcutoff: Double
    private var x: LowPassFilter
    private var dx: LowPassFilter
    private var lasttime: Double?
    
    init(freq: Double = 120.0, mincutoff: Double = 1.0, beta: Double = 0.0, dcutoff: Double = 1.0) {
        precondition(freq > 0 && mincutoff > 0 && dcutoff > 0, "Parameters must be > 0")
        
        self.freq = freq
        self.mincutoff = mincutoff
        self.beta = beta
        self.dcutoff = dcutoff
        
        let teMin = 1.0 / freq
        let tauMin = 1.0 / (2.0 * Double.pi * mincutoff)
        let alphaMin = 1.0 / (1.0 + tauMin / teMin)
        
        let teDc = 1.0 / freq
        let tauDc = 1.0 / (2.0 * Double.pi * dcutoff)
        let alphaDc = 1.0 / (1.0 + tauDc / teDc)
        
        self.x = LowPassFilter(alpha: alphaMin)
        self.dx = LowPassFilter(alpha: alphaDc)
    }
    
    private func alpha(cutoff: Double) -> Double {
        let te = 1.0 / freq
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / te)
    }
    
    func filter(_ value: Double, timestamp: Double? = nil) -> Double {
        if let lasttime = lasttime, let timestamp = timestamp, timestamp > lasttime {
            freq = 1.0 / (timestamp - lasttime)
        }
        lasttime = timestamp
        
        let prevX = x.lastFilteredValue()
        let dxValue = prevX == nil ? 0.0 : (value - prevX!) * freq
        let edx = dx.filter(value: dxValue, timestamp: timestamp, alpha: alpha(cutoff: dcutoff))
        
        let cutoff = mincutoff + beta * abs(edx)
        return x.filter(value: value, timestamp: timestamp, alpha: alpha(cutoff: cutoff))
    }
    
    func reset() {
        x.reset()
        dx.reset()
        lasttime = nil
    }
}

// Test the OneEuroFilter
// let ts: [Double] = [0.0, 0.00833333, 0.0166667, 0.025, 0.0333333, 0.0416667, 0.05, 0.0583333, 0.0666667, 0.075, 0.0833333, 0.0916667, 0.1, 0.108333, 0.116667, 0.125, 0.133333, 0.141667, 0.15, 0.158333, 0.166667, 0.175, 0.183333, 0.191667, 0.2, 0.208333, 0.216667, 0.225, 0.233333, 0.241667, 0.25, 0.258333, 0.266667, 0.275, 0.283333, 0.291667, 0.3, 0.308333, 0.316667, 0.325, 0.333333, 0.341667, 0.35, 0.358333, 0.366667, 0.375, 0.383333, 0.391667, 0.4, 0.408333, 0.416667, 0.425, 0.433333, 0.441667, 0.45, 0.458333, 0.466667, 0.475, 0.483333, 0.491667, 0.5, 0.508333, 0.516667, 0.525, 0.533333, 0.541667, 0.55, 0.558333, 0.566667, 0.575, 0.583333, 0.591667, 0.6, 0.608333, 0.616667, 0.625, 0.633333, 0.641667, 0.65, 0.658333, 0.666667, 0.675, 0.683333, 0.691667, 0.7, 0.708333, 0.716667, 0.725, 0.733333, 0.741667, 0.75, 0.758333, 0.766667, 0.775, 0.783333, 0.791667, 0.8, 0.808333, 0.816667, 0.825, 0.833333, 0.841667, 0.85, 0.858333, 0.866667, 0.875, 0.883333, 0.891667, 0.9, 0.908333, 0.916667, 0.925, 0.933333, 0.941667, 0.95, 0.958333, 0.966667, 0.975, 0.983333, 0.991667, 1.0, 1.00833, 1.01667, 1.025, 1.03333, 1.04167, 1.05, 1.05833, 1.06667, 1.075, 1.08333, 1.09167, 1.1, 1.10833, 1.11667, 1.125, 1.13333, 1.14167, 1.15, 1.15833, 1.16667, 1.175, 1.18333, 1.19167, 1.2, 1.20833, 1.21667, 1.225, 1.23333, 1.24167, 1.25, 1.25833, 1.26667, 1.275, 1.28333, 1.29167, 1.3, 1.30833, 1.31667, 1.325, 1.33333, 1.34167, 1.35, 1.35833, 1.36667, 1.375, 1.38333, 1.39167, 1.4, 1.40833, 1.41667, 1.425, 1.43333, 1.44167, 1.45, 1.45833, 1.46667, 1.475, 1.48333, 1.49167, 1.5, 1.50833, 1.51667, 1.525, 1.53333, 1.54167, 1.55, 1.55833, 1.56667, 1.575, 1.58333, 1.59167, 1.6, 1.60833, 1.61667, 1.625, 1.63333, 1.64167, 1.65, 1.65833, 1.66667, 1.675, 1.68333, 1.69167, 1.7, 1.70833, 1.71667, 1.725, 1.73333, 1.74167, 1.75, 1.75833, 1.76667, 1.775, 1.78333, 1.79167, 1.8, 1.80833, 1.81667, 1.825, 1.83333, 1.84167, 1.85, 1.85833, 1.86667, 1.875, 1.88333, 1.89167, 1.9, 1.90833, 1.91667, 1.925, 1.93333, 1.94167, 1.95, 1.95833, 1.96667, 1.975, 1.98333, 1.99167, 2.0, 2.00833, 2.01667, 2.025, 2.03333, 2.04167, 2.05, 2.05833, 2.06667, 2.075, 2.08333, 2.09167, 2.1, 2.10833, 2.11667, 2.125, 2.13333, 2.14167, 2.15, 2.15833, 2.16667, 2.175, 2.18333, 2.19167, 2.2, 2.20833, 2.21667, 2.225, 2.23333, 2.24167, 2.25, 2.25833, 2.26667, 2.275, 2.28333, 2.29167, 2.3, 2.30833, 2.31667, 2.325, 2.33333, 2.34167, 2.35, 2.35833, 2.36667, 2.375, 2.38333, 2.39167, 2.4, 2.40833, 2.41667, 2.425, 2.43333, 2.44167, 2.45, 2.45833, 2.46667, 2.475, 2.48333, 2.49167, 2.5, 2.50833, 2.51667, 2.525, 2.53333, 2.54167, 2.55, 2.55833, 2.56667, 2.575, 2.58333, 2.59167, 2.6, 2.60833, 2.61667, 2.625, 2.63333, 2.64167, 2.65, 2.65833, 2.66667, 2.675, 2.68333, 2.69167, 2.7, 2.70833, 2.71667, 2.725, 2.73333, 2.74167, 2.75, 2.75833, 2.76667, 2.775, 2.78333, 2.79167, 2.8, 2.80833, 2.81667, 2.825, 2.83333, 2.84167, 2.85, 2.85833, 2.86667, 2.875, 2.88333, 2.89167, 2.9, 2.90833, 2.91667, 2.925, 2.93333, 2.94167, 2.95, 2.95833, 2.96667, 2.975, 2.98333, 2.99167, 3.0, 3.00833, 3.01667, 3.025, 3.03333, 3.04167, 3.05, 3.05833, 3.06667, 3.075, 3.08333, 3.09167, 3.1, 3.10833, 3.11667, 3.125, 3.13333, 3.14167, 3.15, 3.15833, 3.16667, 3.175, 3.18333, 3.19167, 3.2, 3.20833, 3.21667, 3.225, 3.23333, 3.24167, 3.25, 3.25833, 3.26667, 3.275, 3.28333, 3.29167, 3.3, 3.30833, 3.31667, 3.325, 3.33333, 3.34167, 3.35, 3.35833, 3.36667, 3.375, 3.38333, 3.39167, 3.4, 3.40833, 3.41667, 3.425, 3.43333, 3.44167, 3.45, 3.45833, 3.46667, 3.475, 3.48333, 3.49167, 3.5, 3.50833, 3.51667, 3.525, 3.53333, 3.54167, 3.55, 3.55833, 3.56667, 3.575, 3.58333, 3.59167, 3.6, 3.60833, 3.61667, 3.625, 3.63333, 3.64167, 3.65, 3.65833, 3.66667, 3.675, 3.68333, 3.69167, 3.7, 3.70833, 3.71667, 3.725, 3.73333, 3.74167, 3.75, 3.75833, 3.76667, 3.775, 3.78333, 3.79167, 3.8, 3.80833, 3.81667, 3.825, 3.83333, 3.84167, 3.85, 3.85833, 3.86667, 3.875, 3.88333, 3.89167, 3.9, 3.90833, 3.91667, 3.925, 3.93333, 3.94167, 3.95, 3.95833, 3.96667, 3.975, 3.98333, 3.99167, 4.0, 4.00833, 4.01667, 4.025, 4.03333, 4.04167, 4.05, 4.05833, 4.06667, 4.075, 4.08333, 4.09167, 4.1, 4.10833, 4.11667, 4.125, 4.13333, 4.14167, 4.15, 4.15833, 4.16667, 4.175, 4.18333, 4.19167, 4.2, 4.20833, 4.21667, 4.225, 4.23333, 4.24167, 4.25, 4.25833, 4.26667, 4.275, 4.28333, 4.29167, 4.3, 4.30833, 4.31667, 4.325, 4.33333, 4.34167, 4.35, 4.35833, 4.36667, 4.375, 4.38333, 4.39167, 4.4, 4.40833, 4.41667, 4.425, 4.43333, 4.44167, 4.45, 4.45833, 4.46667, 4.475, 4.48333, 4.49167, 4.5, 4.50833, 4.51667, 4.525, 4.53333, 4.54167, 4.55, 4.55833, 4.56667, 4.575, 4.58333, 4.59167, 4.6, 4.60833, 4.61667, 4.625, 4.63333, 4.64167, 4.65, 4.65833, 4.66667, 4.675, 4.68333, 4.69167, 4.7, 4.70833, 4.71667, 4.725, 4.73333, 4.74167, 4.75, 4.75833, 4.76667, 4.775, 4.78333, 4.79167, 4.8, 4.80833, 4.81667, 4.825, 4.83333, 4.84167, 4.85, 4.85833, 4.86667, 4.875, 4.88333, 4.89167, 4.9, 4.90833, 4.91667, 4.925, 4.93333, 4.94167, 4.95, 4.95833, 4.96667, 4.975, 4.98333, 4.99167, 5.0, 5.00833, 5.01667, 5.025, 5.03333, 5.04167, 5.05, 5.05833, 5.06667, 5.075, 5.08333, 5.09167, 5.1, 5.10833, 5.11667, 5.125, 5.13333, 5.14167, 5.15, 5.15833, 5.16667, 5.175, 5.18333, 5.19167, 5.2, 5.20833, 5.21667, 5.225, 5.23333, 5.24167, 5.25, 5.25833, 5.26667, 5.275, 5.28333, 5.29167, 5.3, 5.30833, 5.31667, 5.325, 5.33333, 5.34167, 5.35, 5.35833, 5.36667, 5.375, 5.38333, 5.39167, 5.4, 5.40833, 5.41667, 5.425, 5.43333, 5.44167, 5.45, 5.45833, 5.46667, 5.475, 5.48333, 5.49167, 5.5, 5.50833, 5.51667, 5.525, 5.53333, 5.54167, 5.55, 5.55833, 5.56667, 5.575, 5.58333, 5.59167, 5.6, 5.60833, 5.61667, 5.625, 5.63333, 5.64167, 5.65, 5.65833, 5.66667, 5.675, 5.68333, 5.69167, 5.7, 5.70833, 5.71667, 5.725, 5.73333, 5.74167, 5.75, 5.75833, 5.76667, 5.775, 5.78333, 5.79167, 5.8, 5.80833, 5.81667, 5.825, 5.83333, 5.84167, 5.85, 5.85833, 5.86667, 5.875, 5.88333, 5.89167, 5.9, 5.90833, 5.91667, 5.925, 5.93333, 5.94167, 5.95, 5.95833, 5.96667, 5.975, 5.98333, 5.99167, 6.0, 6.00833, 6.01667, 6.025, 6.03333, 6.04167, 6.05, 6.05833, 6.06667, 6.075, 6.08333, 6.09167, 6.1, 6.10833, 6.11667, 6.125, 6.13333, 6.14167, 6.15, 6.15833, 6.16667, 6.175, 6.18333, 6.19167, 6.2, 6.20833, 6.21667, 6.225, 6.23333, 6.24167, 6.25, 6.25833, 6.26667, 6.275, 6.28333, 6.29167, 6.3, 6.30833, 6.31667, 6.325, 6.33333, 6.34167, 6.35, 6.35833, 6.36667, 6.375, 6.38333, 6.39167, 6.4, 6.40833, 6.41667, 6.425, 6.43333, 6.44167, 6.45, 6.45833, 6.46667, 6.475, 6.48333, 6.49167, 6.5, 6.50833, 6.51667, 6.525, 6.53333, 6.54167, 6.55, 6.55833, 6.56667, 6.575, 6.58333, 6.59167, 6.6, 6.60833, 6.61667, 6.625, 6.63333, 6.64167, 6.65, 6.65833, 6.66667, 6.675, 6.68333, 6.69167, 6.7, 6.70833, 6.71667, 6.725, 6.73333, 6.74167, 6.75, 6.75833, 6.76667, 6.775, 6.78333, 6.79167, 6.8, 6.80833, 6.81667, 6.825, 6.83333, 6.84167, 6.85, 6.85833, 6.86667, 6.875, 6.88333, 6.89167, 6.9, 6.90833, 6.91667, 6.925, 6.93333, 6.94167, 6.95, 6.95833, 6.96667, 6.975, 6.98333, 6.99167, 7.0, 7.00833, 7.01667, 7.025, 7.03333, 7.04167, 7.05, 7.05833, 7.06667, 7.075, 7.08333, 7.09167, 7.1, 7.10833, 7.11667, 7.125, 7.13333, 7.14167, 7.15, 7.15833, 7.16667, 7.175, 7.18333, 7.19167, 7.2, 7.20833, 7.21667, 7.225, 7.23333, 7.24167, 7.25, 7.25833, 7.26667, 7.275, 7.28333, 7.29167, 7.3, 7.30833, 7.31667, 7.325, 7.33333, 7.34167, 7.35, 7.35833, 7.36667, 7.375, 7.38333, 7.39167, 7.4, 7.40833, 7.41667, 7.425, 7.43333, 7.44167, 7.45, 7.45833, 7.46667, 7.475, 7.48333, 7.49167, 7.5, 7.50833, 7.51667, 7.525, 7.53333, 7.54167, 7.55, 7.55833, 7.56667, 7.575, 7.58333, 7.59167, 7.6, 7.60833, 7.61667, 7.625, 7.63333, 7.64167, 7.65, 7.65833, 7.66667, 7.675, 7.68333, 7.69167, 7.7, 7.70833, 7.71667, 7.725, 7.73333, 7.74167, 7.75, 7.75833, 7.76667, 7.775, 7.78333, 7.79167, 7.8, 7.80833, 7.81667, 7.825, 7.83333, 7.84167, 7.85, 7.85833, 7.86667, 7.875, 7.88333, 7.89167, 7.9, 7.90833, 7.91667, 7.925, 7.93333, 7.94167, 7.95, 7.95833, 7.96667, 7.975, 7.98333, 7.99167, 8.0, 8.00833, 8.01667, 8.025, 8.03333, 8.04167, 8.05, 8.05833, 8.06667, 8.075, 8.08333, 8.09167, 8.1, 8.10833, 8.11667, 8.125, 8.13333, 8.14167, 8.15, 8.15833, 8.16667, 8.175, 8.18333, 8.19167, 8.2, 8.20833, 8.21667, 8.225, 8.23333, 8.24167, 8.25, 8.25833, 8.26667, 8.275, 8.28333, 8.29167, 8.3, 8.30833, 8.31667, 8.325, 8.33333, 8.34167, 8.35, 8.35833, 8.36667, 8.375, 8.38333, 8.39167, 8.4, 8.40833, 8.41667, 8.425, 8.43333, 8.44167, 8.45, 8.45833, 8.46667, 8.475, 8.48333, 8.49167, 8.5, 8.50833, 8.51667, 8.525, 8.53333, 8.54167, 8.55, 8.55833, 8.56667, 8.575, 8.58333, 8.59167, 8.6, 8.60833, 8.61667, 8.625, 8.63333, 8.64167, 8.65, 8.65833, 8.66667, 8.675, 8.68333, 8.69167, 8.7, 8.70833, 8.71667, 8.725, 8.73333, 8.74167, 8.75, 8.75833, 8.76667, 8.775, 8.78333, 8.79167, 8.8, 8.80833, 8.81667, 8.825, 8.83333, 8.84167, 8.85, 8.85833, 8.86667, 8.875, 8.88333, 8.89167, 8.9, 8.90833, 8.91667, 8.925, 8.93333, 8.94167, 8.95, 8.95833, 8.96667, 8.975, 8.98333, 8.99167, 9.0, 9.00833, 9.01667, 9.025, 9.03333, 9.04167, 9.05, 9.05833, 9.06667, 9.075, 9.08333, 9.09167, 9.1, 9.10833, 9.11667, 9.125, 9.13333, 9.14167, 9.15, 9.15833, 9.16667, 9.175, 9.18333, 9.19167, 9.2, 9.20833, 9.21667, 9.225, 9.23333, 9.24167, 9.25, 9.25833, 9.26667, 9.275, 9.28333, 9.29167, 9.3, 9.30833, 9.31667, 9.325, 9.33333, 9.34167, 9.35, 9.35833, 9.36667, 9.375, 9.38333, 9.39167, 9.4, 9.40833, 9.41667, 9.425, 9.43333, 9.44167, 9.45, 9.45833, 9.46667, 9.475, 9.48333, 9.49167, 9.5, 9.50833, 9.51667, 9.525, 9.53333, 9.54167, 9.55, 9.55833, 9.56667, 9.575, 9.58333, 9.59167, 9.6, 9.60833, 9.61667, 9.625, 9.63333, 9.64167, 9.65, 9.65833, 9.66667, 9.675, 9.68333, 9.69167, 9.7, 9.70833, 9.71667, 9.725, 9.73333, 9.74167, 9.75, 9.75833, 9.76667, 9.775, 9.78333, 9.79167, 9.8, 9.80833, 9.81667, 9.825, 9.83333, 9.84167, 9.85, 9.85833, 9.86667, 9.875, 9.88333, 9.89167, 9.9, 9.90833, 9.91667, 9.925, 9.93333, 9.94167, 9.95, 9.95833, 9.96667, 9.975, 9.98333, 9.99167]
// let noisy: [Double] = [-0.0385099, -0.0280664, 0.048622, 0.111498, 0.053026, 0.120548, 0.00972308, 0.074193, -0.0236801, 0.0462396, 0.0892027, 0.158329, 0.0423086, 0.0887203, 0.039102, 0.140277, 0.156938, 0.0961089, 0.216881, 0.067538, 0.0737634, 0.0989231, 0.148209, 0.0959887, 0.225627, 0.292078, 0.185221, 0.133595, 0.216387, 0.316189, 0.156782, 0.164811, 0.167903, 0.273214, 0.305514, 0.342528, 0.334796, 0.210729, 0.401551, 0.267666, 0.365411, 0.429558, 0.400613, 0.377235, 0.290475, 0.3709, 0.343945, 0.409876, 0.449394, 0.408817, 0.460212, 0.350016, 0.460729, 0.460575, 0.422736, 0.494404, 0.370493, 0.458812, 0.437653, 0.540203, 0.562047, 0.499726, 0.45569, 0.488606, 0.414257, 0.547406, 0.48588, 0.506342, 0.523481, 0.517879, 0.509856, 0.460493, 0.653243, 0.474117, 0.655405, 0.565535, 0.610696, 0.602161, 0.613684, 0.636438, 0.526166, 0.552988, 0.659328, 0.537982, 0.646424, 0.723758, 0.753106, 0.618995, 0.593751, 0.682406, 0.648052, 0.601187, 0.656204, 0.655082, 0.737839, 0.790659, 0.723829, 0.714996, 0.695523, 0.70248, 0.785328, 0.793889, 0.742967, 0.835997, 0.794085, 0.669877, 0.684952, 0.728392, 0.817913, 0.87136, 0.756231, 0.706382, 0.751949, 0.764369, 0.840366, 0.778078, 0.910647, 0.771871, 0.882991, 0.771255, 0.880222, 0.940582, 0.83384, 0.818352, 0.926818, 0.911038, 0.890403, 0.888671, 0.802989, 0.790784, 0.923662, 0.886855, 0.797806, 0.899139, 0.990704, 0.962132, 0.841881, 0.929136, 0.81661, 0.857319, 0.984367, 0.870154, 0.9616, 0.838021, 0.862438, 0.952181, 0.85446, 0.952981, 0.973629, 0.879962, 1.00331, 0.943755, 1.04803, 0.955519, 0.89716, 0.990258, 0.930495, 1.06566, 1.03265, 1.00126, 1.05601, 0.940871, 1.04812, 0.93925, 1.06181, 0.908907, 0.914178, 1.03277, 1.05168, 0.965001, 1.08447, 1.05485, 0.912772, 1.08674, 0.948473, 1.04851, 0.918663, 0.998624, 0.928149, 1.04254, 0.977894, 0.971627, 0.911533, 0.948634, 0.92056, 1.04865, 0.942962, 0.999262, 0.904246, 1.01354, 1.04384, 0.949724, 1.07556, 1.03091, 0.935323, 1.05314, 0.930579, 1.09324, 1.03678, 1.00796, 0.932059, 1.08245, 0.975399, 1.03516, 1.07061, 0.975585, 0.959802, 1.07458, 1.04762, 1.07037, 0.921807, 0.942086, 0.902779, 0.964481, 1.01122, 0.986976, 0.969665, 1.07034, 0.881189, 0.962377, 0.952177, 0.895071, 1.03435, 0.859543, 0.90227, 0.886349, 0.895146, 0.849935, 1.00719, 0.874621, 0.868176, 0.866467, 0.968107, 0.957349, 0.971171, 0.968437, 1.00345, 0.867785, 0.959463, 0.996814, 0.840355, 0.994387, 0.809371, 0.930054, 0.970108, 0.91396, 0.85715, 0.904599, 0.861406, 0.843549, 0.877406, 0.883933, 0.95528, 0.89457, 0.940222, 0.832032, 0.879813, 0.938163, 0.811391, 0.919585, 0.891743, 0.853485, 0.742877, 0.786175, 0.900227, 0.711621, 0.710777, 0.754724, 0.730897, 0.763726, 0.727071, 0.786783, 0.781291, 0.82116, 0.718125, 0.732673, 0.83153, 0.8028, 0.67734, 0.67548, 0.691861, 0.728598, 0.727649, 0.777535, 0.626144, 0.661974, 0.722082, 0.642391, 0.743098, 0.601154, 0.626336, 0.705339, 0.720785, 0.710128, 0.545971, 0.651172, 0.60873, 0.662059, 0.680956, 0.704665, 0.525335, 0.571052, 0.488002, 0.501072, 0.50367, 0.551055, 0.620131, 0.500137, 0.54037, 0.54802, 0.579951, 0.512952, 0.563287, 0.443482, 0.590761, 0.40942, 0.492231, 0.553133, 0.561166, 0.561312, 0.555419, 0.390766, 0.483065, 0.497034, 0.525594, 0.501019, 0.329897, 0.437562, 0.401387, 0.312853, 0.289332, 0.400447, 0.372821, 0.379365, 0.300605, 0.334611, 0.421584, 0.342735, 0.273586, 0.228108, 0.377484, 0.223262, 0.233684, 0.36955, 0.36546, 0.260799, 0.163995, 0.242763, 0.236595, 0.221315, 0.136039, 0.290271, 0.119666, 0.264658, 0.2878, 0.197194, 0.187655, 0.0782684, 0.22578, 0.0561476, 0.237257, 0.101042, 0.0723786, 0.209619, 0.0410192, 0.146597, 0.0927221, 0.0171409, 0.0382186, 0.103041, 0.0728116, -0.0168824, 0.140865, 0.111984, 0.0611018, 0.0663637, -0.0763146, -0.0325633, -0.0551868, -0.040249, 0.0568236, -0.023862, -0.117245, -0.0536684, -0.0204385, -0.0820722, 0.0153436, -0.0195079, -0.157894, -0.100792, -0.188343, -0.169006, -0.207471, -0.0528409, -0.105652, -0.181442, -0.219727, -0.086656, -0.158067, -0.149939, -0.139416, -0.280468, -0.17473, -0.305268, -0.158464, -0.174769, -0.223604, -0.283438, -0.282646, -0.220254, -0.349833, -0.243244, -0.378364, -0.236902, -0.319945, -0.407357, -0.267149, -0.291404, -0.431519, -0.390778, -0.307564, -0.367601, -0.465211, -0.280323, -0.370825, -0.37341, -0.394264, -0.332231, -0.439595, -0.479596, -0.433972, -0.378641, -0.48315, -0.519333, -0.50383, -0.549269, -0.566041, -0.522325, -0.401423, -0.586108, -0.528588, -0.526246, -0.470659, -0.517238, -0.478972, -0.462968, -0.613985, -0.516697, -0.60137, -0.533471, -0.650175, -0.634433, -0.680072, -0.622689, -0.563904, -0.624583, -0.625285, -0.692517, -0.644846, -0.54603, -0.575679, -0.648791, -0.56108, -0.664147, -0.74794, -0.645917, -0.723812, -0.643557, -0.741776, -0.644202, -0.639321, -0.750869, -0.713365, -0.759742, -0.642367, -0.767799, -0.803195, -0.648656, -0.719967, -0.717422, -0.678092, -0.666642, -0.737129, -0.796617, -0.697477, -0.834111, -0.740656, -0.85579, -0.838512, -0.715314, -0.899276, -0.879134, -0.818637, -0.879782, -0.914533, -0.90626, -0.766519, -0.805935, -0.91742, -0.875509, -0.895285, -0.879054, -0.894239, -0.921757, -0.844164, -0.965658, -0.966041, -0.87088, -0.799261, -0.81828, -0.838928, -0.868247, -0.894703, -0.834394, -0.962987, -0.834651, -0.963765, -0.922053, -0.865554, -0.970832, -0.917005, -0.88314, -1.03335, -0.888257, -0.948224, -1.00717, -1.02564, -0.943412, -0.907098, -0.972586, -0.938077, -0.987552, -1.04947, -0.913828, -1.01899, -0.919595, -0.889748, -1.02571, -1.00096, -1.02559, -0.957968, -1.00453, -0.898139, -0.889598, -0.88522, -0.9755, -0.949051, -1.01151, -1.03018, -1.08755, -1.08693, -0.914057, -1.07874, -1.04296, -0.96527, -1.02252, -1.07639, -0.97092, -1.06901, -0.984933, -0.915461, -0.911268, -1.01977, -0.962878, -1.09796, -1.04046, -0.940494, -1.0396, -0.95414, -0.917353, -0.95839, -0.938247, -1.05607, -0.949062, -1.02025, -1.04109, -0.987285, -0.960422, -0.90956, -1.06769, -1.07638, -0.950008, -1.01897, -0.910603, -0.975565, -0.931398, -0.911561, -0.960576, -0.959819, -0.979929, -1.05892, -1.03278, -0.923962, -0.97137, -1.01667, -0.951035, -0.969811, -1.01118, -1.00492, -0.967642, -0.905763, -0.869976, -0.884454, -1.02131, -1.02475, -0.852387, -0.949486, -0.921439, -0.884198, -1.01116, -0.852881, -1.02554, -0.888208, -0.870573, -0.948854, -0.975161, -0.936234, -0.983146, -0.993616, -0.986699, -0.803351, -0.80314, -0.840797, -0.969963, -0.923497, -0.873537, -0.91995, -0.942455, -0.957088, -0.900984, -0.771593, -0.899414, -0.80548, -0.885008, -0.909306, -0.882762, -0.740996, -0.820888, -0.893306, -0.721799, -0.857902, -0.736714, -0.886138, -0.759533, -0.739206, -0.880657, -0.742419, -0.784683, -0.839748, -0.75136, -0.764241, -0.677803, -0.849813, -0.8305, -0.714652, -0.804725, -0.688006, -0.672292, -0.69021, -0.795854, -0.76267, -0.680616, -0.661496, -0.58839, -0.779513, -0.661368, -0.693113, -0.695693, -0.722039, -0.736403, -0.738569, -0.695269, -0.666656, -0.620466, -0.679624, -0.671886, -0.654554, -0.507857, -0.61305, -0.546608, -0.499738, -0.4923, -0.48034, -0.531177, -0.488741, -0.633654, -0.620426, -0.551659, -0.466036, -0.505663, -0.417878, -0.53532, -0.477283, -0.543153, -0.49115, -0.511793, -0.445562, -0.444969, -0.363686, -0.473087, -0.518512, -0.437476, -0.432785, -0.448887, -0.435234, -0.407001, -0.410809, -0.387206, -0.319375, -0.359473, -0.401968, -0.347434, -0.349792, -0.336015, -0.362737, -0.225621, -0.251945, -0.203662, -0.374702, -0.271813, -0.195223, -0.254921, -0.227165, -0.287958, -0.280216, -0.313683, -0.251383, -0.285225, -0.267148, -0.301452, -0.155991, -0.126165, -0.229554, -0.0794486, -0.0736363, -0.200558, -0.189044, -0.0566984, -0.090654, -0.112543, -0.0794328, -0.0337406, -0.0526936, -0.088401, -0.0317388, -0.0251936, -0.0327765, 0.0215932, 0.0360267, -0.0251824, -0.0704359, 0.00239546, -0.11184, -0.0835358, -0.0167085, 0.101254, 0.0553228, 0.0439169, 0.125805, 0.029874, -0.033129, -0.0253708, 0.12335, 0.095891, 0.0987936, 0.0731513, 0.191736, 0.0413992, 0.0406376, 0.0778773, 0.140164, 0.108751, 0.22887, 0.10603, 0.159205, 0.258977, 0.119131, 0.120417, 0.146056, 0.290491, 0.273001, 0.231698, 0.206742, 0.187256, 0.175311, 0.181794, 0.192588, 0.355709, 0.20045, 0.3369, 0.360634, 0.297796, 0.357495, 0.25708, 0.298206, 0.374233, 0.415999, 0.425967, 0.404664, 0.419603, 0.383499, 0.296801, 0.301941, 0.47503, 0.430538, 0.34879, 0.391486, 0.437048, 0.351241, 0.446324, 0.462107, 0.397081, 0.503465, 0.438999, 0.425616, 0.518416, 0.396401, 0.447712, 0.55946, 0.43228, 0.427166, 0.585364, 0.54067, 0.503502, 0.597501, 0.639627, 0.493301, 0.476214, 0.648065, 0.583554, 0.632462, 0.615183, 0.668667, 0.545038, 0.600823, 0.56565, 0.714979, 0.734157, 0.643412, 0.61011, 0.57806, 0.750217, 0.589634, 0.647672, 0.639361, 0.702005, 0.707377, 0.738203, 0.783992, 0.729519, 0.787579, 0.819872, 0.63363, 0.772062, 0.755057, 0.767696, 0.671395, 0.685242, 0.833504, 0.77125, 0.675723, 0.837003, 0.87603, 0.699638, 0.708806, 0.721008, 0.864423, 0.84629, 0.810794, 0.91783, 0.899027, 0.857398, 0.734758, 0.832483, 0.789397, 0.898977, 0.837321, 0.813519, 0.793261, 0.943382, 0.845543, 0.887664, 0.855036, 0.942652, 0.981103, 0.926326, 0.825084, 0.837796, 0.895125, 0.883461, 0.94962, 0.840487, 0.864223, 0.879687, 0.91232, 1.00241, 0.886389, 1.02094, 0.933522, 0.962482, 0.911022, 0.927301, 0.921034, 0.899343, 0.941212, 0.928469, 0.969659, 0.982075, 0.894388, 0.8906, 0.892288, 1.05886, 1.03514, 1.06361, 1.02327, 0.974105, 1.05007, 0.971763, 0.991878, 0.927951, 0.898885, 0.943753, 0.924388, 0.895313, 1.03376, 0.892019, 0.905185, 1.03719, 1.03613, 1.08675, 0.90282, 1.07703, 0.982483, 1.00727, 0.945193, 0.978191, 1.08402, 0.957197, 0.925405, 0.983109, 0.975106, 0.983278, 1.03135, 1.0868, 1.04001, 1.00335, 0.954956, 0.978079, 0.907946, 1.04005, 0.986177, 1.0809, 0.903728, 1.04036, 0.974833, 1.03516, 0.908613, 1.0442, 0.959666, 0.901561, 0.986289, 1.00328, 0.960558, 1.00123, 1.01052, 0.922922, 0.885273, 1.02301, 0.878942, 1.04734, 1.05641, 1.03097, 1.06128, 0.926944, 1.05393, 0.928097, 0.971062, 0.930882, 1.0018, 0.865317, 0.963111, 0.904217, 0.907091, 0.962224, 1.03241, 0.929711, 0.981366, 0.889291, 1.01772, 0.911283, 0.957577, 0.914198, 0.995168, 0.900067, 0.842714, 0.865969, 0.952152, 0.91008, 0.949864, 0.991078, 0.913836, 0.978619, 0.884397, 0.844027, 0.91085, 0.787544, 0.789668, 0.902077, 0.782669, 0.916563, 0.910948, 0.744039, 0.922012, 0.885486, 0.755273, 0.803735, 0.801887, 0.809972, 0.901934, 0.868949, 0.800965, 0.840854, 0.828538, 0.741353, 0.842706, 0.810932, 0.832942, 0.703623, 0.692316, 0.785885, 0.804902, 0.717177, 0.688055, 0.653466, 0.802159, 0.622045, 0.614677, 0.801858, 0.794712, 0.757625, 0.720759, 0.605402, 0.689877, 0.757276, 0.616486, 0.609681, 0.681802, 0.609363, 0.693669, 0.535942, 0.669837, 0.639525, 0.699703, 0.560724, 0.691577, 0.605265, 0.518528, 0.581552, 0.545368, 0.613351, 0.487809, 0.637202, 0.458049, 0.475053, 0.51769, 0.604145, 0.550181, 0.503593, 0.413167, 0.528737, 0.410687, 0.423158, 0.452975, 0.39562, 0.38261, 0.406644, 0.371752, 0.494154, 0.369652, 0.4416, 0.338976, 0.501042, 0.377114, 0.448077, 0.297639, 0.318834, 0.416828, 0.31437, 0.446225, 0.28891, 0.264039, 0.426548, 0.281466, 0.215918, 0.268862, 0.371633, 0.278706, 0.224909, 0.369085, 0.182955, 0.243792, 0.192398, 0.16925, 0.160891, 0.202132, 0.142646, 0.211676, 0.10497, 0.240247, 0.227592, 0.133644, 0.152102, 0.196637, 0.107136, 0.0581238, 0.0779516, 0.0562242, 0.170741, 0.0854623, 0.17632, 0.112703, 0.118099, 0.113249, 0.0125737, 0.071491, 0.0715231, 0.0567269, 0.080988, -0.00940782, 0.0986729, 0.0306066, 0.0791586, -0.058051, -0.0923587, -0.0628835, -0.0553634, -0.0755849, 0.0112573, -0.130728, -0.0354732, -0.113537, -0.031496, -0.163644, -0.0584371, -0.0468514, -0.039507, -0.0403326, -0.0918269, -0.0788014, -0.235022, -0.0775291, -0.108875, -0.133145, -0.234253, -0.163585, -0.262359, -0.184439, -0.240537, -0.198045, -0.192938, -0.176274, -0.184832, -0.194244, -0.233379, -0.334033, -0.298427, -0.234063, -0.386474, -0.205942, -0.38076, -0.295968, -0.302746, -0.297446, -0.27695, -0.255507, -0.316329, -0.422299, -0.342478, -0.289509, -0.394837, -0.430323, -0.494116, -0.377105, -0.349282, -0.386081, -0.429214, -0.418848, -0.361343, -0.555375, -0.452876, -0.481109, -0.481479, -0.5262, -0.5396, -0.507052, -0.411071, -0.57994, -0.477079, -0.605569, -0.470367]
// let f = OneEuroFilter(
//   mincutoff: 1.0,
//   beta: 0.1,       
//   dcutoff: 1.0
// )
// print("timestamp,noisy,filtered")
// for (t, n) in zip(ts, noisy) {
//   let filtered = f.filter(n, timestamp: t)
//   print("\(t),\(n),\(filtered)")
// }
