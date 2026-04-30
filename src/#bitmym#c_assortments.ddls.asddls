@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Assortment list'
@Metadata.ignorePropagatedAnnotations: true
define view entity /BITMYM/C_ASSORTMENTS as select distinct from /BITMYM/C_PRODUCT_CATALOG_ADV
  association [0..*] to /BITMYM/I_ASSORTMENT_ITEMS      as _Items on _Items.SalesDocument = $projection.NodeID
{
  key NodeID,
      NodeText,
      NodeObjectType,
      _Characteristics,
      _Items
}
where NodeObjectType = 'O'
