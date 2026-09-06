#ifndef CALC_CALCULUS_STRATEGY
#define CALC_CALCULUS_STRATEGY

#include "IStrategy.mqh"
#include "FlowEngine.mqh"

class CCalculusStrategy : public IStrategy { 
private: 
    CFlowEngine* m_engine;
    
    // Dynamic storage for scalable weights
    double m_weights[];
    
    // Thresholds & Multipliers
    double m_velThresh, m_accThresh, m_jerkThresh, m_snapThresh, m_crackleThresh, m_popThresh;
    double m_velMult, m_accMult, m_jerkMult, m_snapMult, m_crackleMult, m_popMult, m_asymmetryMult, m_decisionThreshold;

public:
    CCalculusStrategy() : m_engine(NULL) { ArrayResize(m_weights, 0); }

    ~CCalculusStrategy() { if(m_engine != NULL) { delete m_engine; m_engine = NULL; } }

    void InitEngine() {
        if(m_engine == NULL) m_engine = new CFlowEngine();
    }
    
    // Use this to pass any number of weights dynamically
    void SetWeights(double &w[]) {
        int size = ArraySize(w);
        ArrayResize(m_weights, size);
        ArrayCopy(m_weights, w);
    }
    
    void SetStrategyParams(double vT, double vM, double aT, double aM, double jT, double jM, double sT, double sM, double cT, double cM, double pT, double pM, double asym, double decT) {
        m_velThresh = vT; m_velMult = vM; m_accThresh = aT; m_accMult = aM; m_jerkThresh = jT; m_jerkMult = jM; 
        m_snapThresh = sT; m_snapMult = sM; m_crackleThresh = cT; m_crackleMult = cM; m_popThresh = pT; m_popMult = pM; 
        m_asymmetryMult = asym; m_decisionThreshold = decT;
    }

    CFlowEngine* GetEngine() { return m_engine; }

    // Required Interface Overrides
    string Analyze(double &data[]) override {
        if(m_engine == NULL || !m_engine.IsReady()) return "HOLD";
        
        // Pass data to engine dynamically
        m_engine.UpdatePhysics(data); 
        
        int numStreams = ArraySize(data);
        double totalScore = 0.0;

        for(int s = 0; s < numStreams; s++) {
            double vel = m_engine.Derive(1, s);
            double acc = m_engine.Derive(2, s);
            double jrk = m_engine.Derive(3, s);
            double snp = m_engine.Derive(4, s);
            double crc = m_engine.Derive(5, s);
            double pop = m_engine.Derive(6, s);

            double streamScore = (vel * m_velMult * (vel > m_velThresh ? 1.0 : 0.0)) +
                                 (acc * m_accMult * (acc > m_accThresh ? 1.0 : 0.0)) +
                                 (jrk * m_jerkMult * (jrk > m_jerkThresh ? 1.0 : 0.0)) +
                                 (snp * m_snapMult * (snp > m_snapThresh ? 1.0 : 0.0)) +
                                 (crc * m_crackleMult * (crc > m_crackleThresh ? 1.0 : 0.0)) +
                                 (pop * m_popMult * (pop > m_popThresh ? 1.0 : 0.0));
            
            // Apply dynamic weight if it exists, otherwise default to 1.0
            double weight = (s < ArraySize(m_weights)) ? m_weights[s] : 1.0;
            totalScore += (streamScore * weight);
        }

        if(totalScore < 0) totalScore *= m_asymmetryMult;

        if(totalScore > m_decisionThreshold) return "BUY";
        if(totalScore < -m_decisionThreshold) return "SELL";
        
        return "HOLD";
    }

    double GetVelocity(int s)     override { return m_engine.Derive(1, s); }
    double GetAcceleration(int s) override { return m_engine.Derive(2, s); }
    double GetJerk(int s)         override { return m_engine.Derive(3, s); }
};
#endif