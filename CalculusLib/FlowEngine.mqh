//+------------------------------------------------------------------+
//| FlowEngine.mqh (Dynamic/Refactored)                              |
//+------------------------------------------------------------------+
#define ERR_CALC_NOT_READY 0.0

class CFlowEngine {
private:
    double m_buffers[][15]; // Dynamic 2D buffer
    int m_ptr;
    bool m_ready;
    int m_numStreams;

public:
    CFlowEngine() : m_ptr(0), m_ready(false), m_numStreams(0) { }
    
    // Call this to initialize the buffer size based on your current data input count
    void Init(int numStreams) {
        m_numStreams = numStreams;
        ArrayResize(m_buffers, m_numStreams);
        ArrayInitialize(m_buffers, 0.0);
    }
    
    struct FlowState { 
        double Velocity, Acceleration, Jerk, Snap, Crackle, Pop; 
    };
    
    // Updated to require the stream index 's'
    FlowState GetFlowState(int s) {
        FlowState st;
        st.Velocity     = Derive(1, s);
        st.Acceleration = Derive(2, s);
        st.Jerk         = Derive(3, s);
        st.Snap         = Derive(4, s);
        st.Crackle      = Derive(5, s);
        st.Pop          = Derive(6, s);
        return st;
    }

    // Dynamic UpdatePhysics that accepts any array size
    void UpdatePhysics(double &data[]) {
        if(ArraySize(data) != m_numStreams) Init(ArraySize(data));
        
        for(int i = 0; i < m_numStreams; i++) {
            m_buffers[i][m_ptr] = data[i];
        }
        if(++m_ptr >= 15) { m_ptr = 0; m_ready = true; }
    }

    double GetSafe(int s, int lag) {
        if(s >= m_numStreams) return 0.0;
        int idx = (m_ptr + lag + 15) % 15;
        return m_buffers[s][idx];
    }
    
    bool IsReady() { return m_ready; }

    double Derive(int order, int s) {
        if(!IsReady() || s >= m_numStreams) return ERR_CALC_NOT_READY;
        
        // Derivatives calculations remain unchanged but now access dynamic buffers
        double v1 = GetSafe(s, -1) - GetSafe(s, -2);
        double v2 = GetSafe(s, -2) - GetSafe(s, -3);
        double v3 = GetSafe(s, -3) - GetSafe(s, -4);
        double v4 = GetSafe(s, -4) - GetSafe(s, -5);
        double v5 = GetSafe(s, -5) - GetSafe(s, -6);
        double v6 = GetSafe(s, -6) - GetSafe(s, -7);
        double a1 = v1 - v2;
        double a2 = v2 - v3;
        double a3 = v3 - v4;
        double a4 = v4 - v5;
        double a5 = v5 - v6;
        double j1 = a1 - a2;
        double j2 = a2 - a3;
        double j3 = a3 - a4;
        double j4 = a4 - a5;
        double s1 = j1 - j2;
        double s2 = j2 - j3;
        double s3 = j3 - j4;
        double c1 = s1 - s2;
        double c2 = s2 - s3;
        double p1 = c1 - c2;
        
        if(order == 1) return v1;
        if(order == 2) return a1;
        if(order == 3) return j1;
        if(order == 4) return s1;
        if(order == 5) return c1;
        if(order == 6) return p1;
        
        return ERR_CALC_NOT_READY;
    }
};