//+-----------------------------------------------------------+
//|  IndicatorBase.mqh                                        |
//|  Common boilerplate for handles and buffers.              |
//+-----------------------------------------------------------+
#include "IFeature.mqh"

class CIndicatorBase : public IFeature {
protected:
   int    m_handle;
   double m_buffer[];

public:
   CIndicatorBase() : m_handle(INVALID_HANDLE) {
      ArraySetAsSeries(m_buffer, true);
   }

   ~CIndicatorBase() {
      if(m_handle != INVALID_HANDLE) IndicatorRelease(m_handle);
   }

   // Common logic to copy the latest value
   double FetchLastValue() {
      if(CopyBuffer(m_handle, 0, 0, 1, m_buffer) < 0) return 0.0;
      return m_buffer[0];
   }
};