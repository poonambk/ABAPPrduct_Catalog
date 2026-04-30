@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '/BITMYM/C_PRODUCT_CATALOG'
@Metadata.ignorePropagatedAnnotations: true
define view entity /BITMYM/C_PRODUCT_CATALOG_ADV
  as select from /BITMYM/I_PRODUCT_CATALOG_ADV
  (  p_root_node: '' ,
     p_max_depth: 99 )
   as H
 association [0..*] to /BITMYM/I_ASSORTMENT_ITEMS      as _Items on _Items.SalesDocument = $projection.NodeID
{
  key H.NodeID,
  key H.ParentNodeID,
      MaxDepth,

      HierarchyLevel,
      HierarchyTreeSize,
      DrillState,
      StatusFlag,

      HierarchyParentRank,
      H.NodeText,
      H.NodeClass,
      H.NodeObjectType,
      H.ParentText,
      _Characteristics,
      _Child,
      _Items
}
