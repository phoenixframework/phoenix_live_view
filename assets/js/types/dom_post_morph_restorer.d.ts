export default class DOMPostMorphRestorer {
    private containerId;
    private updateType;
    private elementsToModify;
    private elementIdsToAdd;
    constructor(containerBefore: Element, containerAfter: Element, updateType: "append" | "prepend");
    perform(): void;
}
