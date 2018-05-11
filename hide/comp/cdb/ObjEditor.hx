package hide.comp.cdb;

class ObjEditor extends Editor {

    public dynamic function onChange(propName : String) {}

    public function new( root : Element, sheet : cdb.Sheet, obj : {} ) {
        var sheetData = Reflect.copy(@:privateAccess sheet.sheet);
        sheetData.lines = [for( i in 0...sheet.columns.length ) obj];
        var pseudoSheet = new cdb.Sheet(sheet.base, sheetData);
        this.displayMode = AllProperties;
        super(root, pseudoSheet);
    }

    override function addChanges( changes : cdb.Database.Changes ) {
        super.addChanges(changes);
        if(changes.length == 1) {
            switch(changes[0].v) {
                case SetField(o, f, v):
                    onChange(f);
                default:
                    onChange(null);
            }
        }
        else
            onChange(null);
    }
}