@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '/BITMYM/C_PRODUCT_CATALOG'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.query.implementedBy: 'ABAP:/BITMYM/CL_PRODUCT_CATALOG_QP'
@Search.searchable: true
define view entity /BITMYM/C_PRODUCT_CATALOG
  as select from /BITMYM/I_PRODUCT_CATALOG_HRY
  (  p_root_node: '' ,
     p_max_depth: 99  )
   as H
{
  key H.NodeID,
  key H.ParentNodeID,
  0 as MaxDepth,
  @Search.defaultSearchElement: true
      H.NodeText,
      H.NodeClass,
      H.NodeObjectType,
      H.ParentText,
      CharValue,
      CharDescription,
      CharId,
      _Characteristics,
      _Child
}
