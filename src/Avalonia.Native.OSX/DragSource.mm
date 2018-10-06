#include "common.h"

class DragSource : public ComSingleObject<IAvnPlatformDragSource, &IID_IAvnPlatformDragSource>
{
    
    
    virtual void DoDragDrop(IAvnDataObject* data, AvnDragDropEffects allowedEffects)
    {
        
    }
};
